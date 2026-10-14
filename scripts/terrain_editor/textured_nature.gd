extends RefCounted
## Existing CC0 meshes, with source UVs/material boundaries preserved.
## Bake node transforms once so bounds, support and MultiMesh agree.
static func build(id:String,height:float)->Dictionary:
 var source:Node=load("res://assets/nature/quaternius/"+id+".gltf").instantiate()
 var parts:Array=[]
 _collect(source,Transform3D.IDENTITY,parts)
 var bounds:=AABB()
 for part:Dictionary in parts:
  var box:AABB=part.pose*part.mesh.get_aabb()
  bounds=box if bounds.size==Vector3.ZERO else bounds.merge(box)
 var scale3:=Vector3.ONE*(height/maxf(bounds.size.y,.0001))
 var foot:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
 var normalize_pose:=Transform3D(Basis.IDENTITY.scaled(scale3),-foot*scale3)
 var joined:=ArrayMesh.new()
 for part:Dictionary in parts:
  for surface in part.mesh.get_surface_count():
   var builder:=SurfaceTool.new()
   builder.begin(Mesh.PRIMITIVE_TRIANGLES)
   builder.append_from(part.mesh,surface,normalize_pose*part.pose)
   builder.index()
   builder.commit(joined)
   var original:StandardMaterial3D=part.materials[surface]
   var label:=original.resource_name.to_lower()
   var leaf:bool="leaves" in label or "flowers" in label or "grass" in label
   var material:=ShaderMaterial.new()
   material.shader=load("res://shaders/terrain_editor/textured_nature.gdshader")
   material.set_shader_parameter("albedo_tex",original.albedo_texture)
   material.set_shader_parameter("is_leaf",leaf)
   material.set_shader_parameter("is_meadow","grass" in label)
   material.set_shader_parameter("preserve_color",.88 if "flowers" in label else 0.0)
   material.set_shader_parameter("plant_height",height)
   joined.surface_set_material(joined.get_surface_count()-1,material)
 source.free()
 return {"mesh":joined,"pose":Transform3D.IDENTITY}

static func _collect(node:Node,parent:Transform3D,parts:Array)->void:
 var pose:=parent
 if node is Node3D:pose=parent*node.transform
 if node is MeshInstance3D:
  var materials:Array=[]
  for surface in node.mesh.get_surface_count():materials.append(node.get_active_material(surface))
  parts.append({"mesh":node.mesh,"pose":pose,"materials":materials})
 for child in node.get_children():_collect(child,pose,parts)
