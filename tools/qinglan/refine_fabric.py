"""Refine the preserved Tripo garment's finish without changing body animation.

Run with Blender --factory-startup -b --python tools/qinglan/refine_fabric.py.
The repeatable textile maps are shading assets, not replacement model geometry.
"""
from pathlib import Path
import bpy
import hashlib
import json
import math
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/work/qinglan/qinglan_clothed_v04.blend'
WORK = ROOT / 'art/work/qinglan/qinglan_fabric_v05.blend'
OUTPUT = ROOT / 'assets/characters/qinglan/qinglan_fabric_v05.glb'
REVIEW = ROOT / 'art/review/fabric_v05'
TEXTURES = ROOT / 'assets/characters/qinglan/fabric_textures'


def smooth(a, b, x):
    t = max(0., min(1., (x-a)/(b-a)))
    return t*t*(3-2*t)


def image_file(name, rgb, noncolor=False):
    size = rgb.shape[0]
    image = bpy.data.images.new(name, width=size, height=size, alpha=False)
    image.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(TEXTURES / (name+'.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    return image


def textile_maps():
    """A restrained plain weave, with slightly irregular yarns and broad dye variation."""
    size = 512
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)/size
    # A 16 cm repeat holds 64 yarns: visible at close zoom, subdued at play distance.
    wx = np.sin(x*math.tau*64 + .13*np.sin(y*math.tau*3))
    wy = np.sin(y*math.tau*64 + .11*np.sin(x*math.tau*5))
    over = np.sin(x*math.tau*32)*np.sin(y*math.tau*32)
    height = .48*wx + .35*wy + .17*over
    dye = .50*np.sin(x*math.tau*3+.4*np.sin(y*math.tau*2)) + .3*np.sin(y*math.tau*5) + .2*np.sin((x+y)*math.tau*11)
    shade = 1 + .018*height + .022*dye
    normal = np.stack((-.15*(np.roll(height,-1,1)-np.roll(height,1,1)),
                       -.15*(np.roll(height,-1,0)-np.roll(height,1,0)), np.ones_like(height)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    normal_image = image_file('fabric_plainweave_normal', normal*.5+.5, True)
    # glTF stores roughness in G and metallic in B.
    orm = np.stack((np.ones_like(height), np.clip(.84+.035*height+.02*dye,.76,.93), np.zeros_like(height)), axis=-1)
    rough_image = image_file('fabric_plainweave_orm', orm, True)
    return shade, normal_image, rough_image


def assign_materials(shade, normal_image, rough_image):
    for name in ['robe','ivory','pants','teal']:
        mat = bpy.data.materials[name]
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes.get('Principled BSDF')
        base = np.array(bsdf.inputs['Base Color'].default_value[:3])
        # Generated image pixels are stored as encoded values. Explicit conversion
        # preserves the original linear palette after the image's sRGB decode.
        linear=np.clip(shade[:,:,None]*base,0,1)
        encoded=np.where(linear<=.0031308,12.92*linear,1.055*np.power(linear,1/2.4)-.055)
        color_image = image_file('fabric_'+name+'_albedo', encoded)
        tex = nodes.new('ShaderNodeTexImage'); tex.image=color_image; tex.label='Subtle yarn and dye variation'
        links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        tex = nodes.new('ShaderNodeTexImage'); tex.image=normal_image
        normal = nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.6
        links.new(tex.outputs['Color'],normal.inputs['Color']); links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
        tex = nodes.new('ShaderNodeTexImage'); tex.image=rough_image
        sep = nodes.new('ShaderNodeSeparateColor')
        links.new(tex.outputs['Color'],sep.inputs['Color']); links.new(sep.outputs['Green'],bsdf.inputs['Roughness'])
        bsdf.inputs['Specular IOR Level'].default_value=.20
        bsdf.inputs['Sheen Weight'].default_value=.16 if name=='teal' else .10
        bsdf.inputs['Sheen Roughness'].default_value=.8
        # glTF's sheen extension has no separate weight input; keep its tint
        # bounded as well so the exported material cannot become white velvet.
        bsdf.inputs['Sheen Tint'].default_value=(.12,.12,.12,1)
        bsdf.inputs['Coat Weight'].default_value=0
        mat['fabric_note']='Plain woven textile; low dielectric specular, fine yarn normal, variable roughness. No cloth simulation.'


def textile_uv(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(65), island_margin=.02, correct_aspect=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh=obj.data; uv=mesh.uv_layers.active
    # Normalize the packed islands to world texel density, rather than scaling
    # a trouser leg and an entire robe to the same size of cloth weave.
    mesh.calc_loop_triangles()
    uv_area = 0.; world_area = 0.
    for tri in mesh.loop_triangles:
        p=[uv.data[i].uv.copy() for i in tri.loops]
        uv_area += abs((p[1]-p[0]).cross(p[2]-p[0]))*.5
        world_area += tri.area
    factor=math.sqrt(world_area/max(uv_area,1e-9))/.16
    for loop in uv.data: loop.uv *= factor
    return {'uv_layer':uv.name,'repeat_meters':.16,'uv_scale':factor}


def refine_drape(robe):
    """Re-form existing vertices; keep shell thickness, bindings and panel topology."""
    marker=robe.vertex_groups.get('__Sleeve')
    changes=[]
    for vertex in robe.data.vertices:
        p=vertex.co.copy(); x,y,z=p
        # v04 skinning deliberately strips the old marker; infer sleeve membership
        # from the unchanged arm bindings and the garment's rest-space location.
        arm=sum(g.weight for g in vertex.groups if robe.vertex_groups[g.group].name.startswith(('UpperArm.','Forearm.','Hand.')))
        sleeve=smooth(.1,.65,arm)*smooth(.15,.27,abs(x))
        lower=(1-smooth(.34,.57,z))*(1-sleeve)
        # Reduce the source's horizontal bell volume, preserve ample leg clearance.
        vertex.co.x *= 1-.07*lower
        vertex.co.y = .025+(y-.025)*(1-.19*lower)
        vertex.co.z -= .010*lower*smooth(.09,.20,abs(y-.025))
        # Slim broad, inflated sleeve faces and add shallow longitudinal creases.
        # A continuous displacement moves both sides of the thin source shell.
        vertex.co.y = vertex.co.y*(1-.12*sleeve)
        crease=math.sin((z-.68)*105+.30*math.sin(abs(x)*11))
        vertex.co.y += .0025*crease*sleeve*smooth(.17,.30,abs(x))
        delta=(vertex.co-p).length
        if delta>1e-7: changes.append(delta)
    robe.data.update()
    # Preserve true panel edges instead of smoothing every fold into a rubber tube.
    robe.data.set_sharp_from_angle(angle=math.radians(58))
    return {'changed_vertices':len(changes),'max_vertex_displacement_m':max(changes),
            'topology_changed':False,'weights_changed':False,
            'description':'Reduce lower bell depth by up to 19%, lateral flare by 7%, sleeve depth by 12%; 2.5 mm shallow sleeve creases.'}


def fit_waistband(obj):
    """Move the existing trouser top below the fitted bodice, retaining every face.

    Diagnostic material renders identify v04's rear white wedges as trousers:
    their top rings reached z=.6163, well above the actual .55-.56 waist.
    Knee support rings, hems and the covered-calf body remain unchanged.
    """
    old_top=max(v.co.z for v in obj.data.vertices)
    ring=list(obj.data.vertices)[:16]
    center=sum((v.co for v in ring), start=np.zeros(3))/16
    for v in ring:
        v.co.x=center[0]+(v.co.x-center[0])*.55
        v.co.y=center[1]+(v.co.y-center[1])*.65
        v.co.z=.553
        for group in obj.vertex_groups:group.remove([v.index])
        hips=obj.vertex_groups.get('Hips') or obj.vertex_groups.new(name='Hips')
        hips.add([v.index],1.,'REPLACE')
    # Blend the narrower waistband into the existing upper thigh ring.
    ring=list(obj.data.vertices)[16:32]
    center=sum((v.co for v in ring), start=np.zeros(3))/16
    for v in ring:
        v.co.x=center[0]+(v.co.x-center[0])*.55
        v.co.y=center[1]+(v.co.y-center[1])*.80
    # Ray inspection of the turn frame locates the remaining long white wedge
    # on trouser faces 0 and 17: upper thighs wider than the fitted robe side.
    # Taper those hidden upper legs, retaining the knee support loops below.
    ring=list(obj.data.vertices)[32:48]
    center=sum((v.co for v in ring), start=np.zeros(3))/16
    for v in ring:
        v.co.x=center[0]+(v.co.x-center[0])*.65
        v.co.y=center[1]+(v.co.y-center[1])*.88
    obj.data.update()
    return {'old_waist_z':old_top,'new_waist_z':.553,'changed_position_vertices':48,
            'changed_weight_vertices':16,'waist_binding':'Hips only',
            'preserved':'All faces; knee and lower-leg positions/weights; covered-calf body.'}


def main():
    REVIEW.mkdir(parents=True,exist_ok=True); TEXTURES.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest()}
    report['drape']=refine_drape(bpy.data.objects['Robe'])
    report['waistband']={s:fit_waistband(bpy.data.objects['WhiteTrousers.'+s]) for s in ['L','R']}
    shade,normal,rough=textile_maps(); assign_materials(shade,normal,rough)
    report['uv']={o.name:textile_uv(o) for o in list(bpy.data.objects) if o.type=='MESH' and o.name!='Body'}
    # Body has an unused pants material slot; its original geometry stays untouched.
    report['actions']=[a.name for a in bpy.data.actions]
    report['simulation']='Not added. Existing skirt/ribbon tracks remain unchanged. This pass addresses shape and surface response.'
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK))
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True)
    report['runtime_sha256']=hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    (REVIEW/'fabric_refinement.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__': main()
