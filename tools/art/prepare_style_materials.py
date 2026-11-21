"""Blender: derive a matte, bounded base-color material source; retain paid originals.

blender -b --factory-startup --python tools/art/prepare_style_materials.py -- \
  --manifest path/manifest.json --out-dir path/new_material_source --max-size 1024
Requires sibling tripo/original_textured.glb. No overwrite and no geometry editing.
"""
import argparse
import hashlib
import json
import sys
from array import array
from pathlib import Path

import bpy


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(args):
    manifest_path = args.manifest.resolve()
    manifest = json.loads(manifest_path.read_text())
    source = manifest_path.parent / 'tripo/original_textured.glb'
    if not source.is_file():
        raise ValueError(f'texture original missing: {source}')
    out = args.out_dir.resolve()
    if out.exists() and any(out.iterdir()):
        raise FileExistsError(f'refusing populated output: {out}')
    if args.max_size not in (256, 512, 1024, 2048):
        raise ValueError('max-size must be 256/512/1024/2048')
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    report = {'source': str(source), 'source_sha256': sha(source), 'manifest': str(manifest_path),
              'blender': bpy.app.version_string, 'tool_sha256': sha(__file__),
              'policy': 'opaque with backface culling, one existing base-color UV texture per material; roughness .92; metallic 0; no normal/ORM/emission textures',
              'max_size': args.max_size, 'materials': [], 'images': []}
    materials = {mat.name: mat for obj in objects for mat in obj.data.materials if mat}
    retained_images = {}
    for mat in materials.values():
        if not mat.use_nodes:
            raise ValueError(f'material has no nodes: {mat.name}')
        principled = next((node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED'), None)
        if principled is None:
            raise ValueError(f'material lacks Principled: {mat.name}')
        links = list(principled.inputs['Base Color'].links)
        if len(links) != 1 or links[0].from_node.type != 'TEX_IMAGE' or not links[0].from_node.image:
            raise ValueError(f'base color must directly use one image: {mat.name}')
        original_image = links[0].from_node.image
        texture_node = links[0].from_node
        if texture_node.inputs['Vector'].is_linked or texture_node.extension != 'REPEAT' or texture_node.interpolation != 'Linear':
            raise ValueError(f'non-default UV mapping/sampling requires separate preservation adapter: {mat.name}')
        if original_image.name not in retained_images:
            before = list(original_image.size)
            # Keep a separate pixel-backed image so the packed original stays untouched.
            # Blender 5.2: assigning colorspace after scale() (even the same name)
            # reloads GENERATED images at generated_width/height, discarding
            # the resized buffer. Set colorspace before copying/scaling; pack()
            # was not the observed resize reset trigger.
            image = bpy.data.images.new(original_image.name + '_runtime', width=before[0], height=before[1], alpha=True)
            image.colorspace_settings.name = original_image.colorspace_settings.name
            pixels = array('f', [0.0]) * (before[0] * before[1] * 4)
            original_image.pixels.foreach_get(pixels)
            image.pixels.foreach_set(pixels)
            image.update()
            del pixels
            ratio = min(1.0, args.max_size / max(before))
            if ratio < 1:
                image.scale(max(1, round(before[0]*ratio)), max(1, round(before[1]*ratio)))
            image.pack()
            if max(image.size) > args.max_size:
                raise ValueError('image exceeds requested runtime size; no runtime export')
            retained_images[original_image.name] = image
            width, height = image.size
            report['images'].append({'original': original_image.name, 'before': before, 'after': [width, height],
                                     'rgba8_with_mips_estimate_bytes': int(width*height*4*4/3)})
        image = retained_images[original_image.name]
        # Deliberate fresh material graph: no orphan PBR image nodes exported.
        nodes = mat.node_tree.nodes
        nodes.clear()
        output = nodes.new('ShaderNodeOutputMaterial')
        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = image
        bsdf.inputs['Roughness'].default_value = .92
        bsdf.inputs['Metallic'].default_value = 0
        bsdf.inputs['Alpha'].default_value = 1
        mat.node_tree.links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])
        mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
        mat.use_backface_culling = True
        report['materials'].append({'name': mat.name, 'base_color_image': image.name})
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    destination = out / 'material_source.glb'
    bpy.ops.export_scene.gltf(filepath=str(destination), export_format='GLB', use_selection=True,
                              export_animations=False, export_apply=False)
    report['output'] = {'file': str(destination), 'sha256': sha(destination), 'bytes': destination.stat().st_size}
    report['estimated_rgba8_texture_bytes_with_mips'] = sum(i['rgba8_with_mips_estimate_bytes'] for i in report['images'])
    (out / 'material_report.json').write_text(json.dumps(report, indent=2)+'\n')
    derived = dict(manifest)
    # Absolute image inputs intentionally remain traceable through source manifest.
    derived['source_glb'] = str(destination)
    derived['source_manifest'] = str(manifest_path)
    derived['original_textured_glb'] = str(source.resolve())
    derived['asset'] = manifest_path.parent.name
    derived['asset_contract'] = dict(manifest.get('asset_contract', {}), runtime_texture_max_size=args.max_size,
                                     material_policy=report['policy'], weld_uv_seam_geometry=True)
    (out / 'manifest_runtime.json').write_text(json.dumps(derived, ensure_ascii=False, indent=2)+'\n')
    print('STYLE_MATERIAL_SOURCE', json.dumps(report))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', required=True, type=Path)
    parser.add_argument('--out-dir', required=True, type=Path)
    parser.add_argument('--max-size', required=True, type=int)
    run(parser.parse_args(sys.argv[sys.argv.index('--')+1:]))
