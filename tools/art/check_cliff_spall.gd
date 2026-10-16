extends SceneTree
## Validate delivered resource bytes, mip chain and quiet-face coverage.
func _initialize()->void:
 var original:Image=load('res://assets/textures/terrain/stone_detail.png').get_image()
 var delivered:Texture2D=load('res://assets/textures/terrain/stone_detail_spall_v3.res')
 var image:Image=delivered.get_image()
 assert(image.has_mipmaps() and image.get_size()==original.get_size())
 original.convert(Image.FORMAT_RGBA8);image.convert(Image.FORMAT_RGBA8)
 var old:=original.get_data();var next:=image.get_data();var mismatch:=0;var quiet:=0;var marked:=0
 assert(old.size()==next.size())
 for i in range(0,next.size(),4):
  if old[i]!=next[i] or old[i+3]!=next[i+3]:mismatch+=1
 for i in range(0,image.get_width()*image.get_height()*4,4):
  var fine:=Vector2(float(old[i+1])/255.0-.5,float(old[i+2])/255.0-.5)*2.0*.07
  var current:=Vector2(float(next[i+1])/255.0-.5,float(next[i+2])/255.0-.5)*2.0*.25
  var change:=fine.distance_to(current)
  if change<.0028:quiet+=1
  if change>.02:marked+=1
 var count:float=image.get_width()*image.get_height()
 assert(mismatch==0 and quiet/count>.55 and marked/count>.10)
 print('DELIVERED SPALL: mipmaps=',image.has_mipmaps(),' value_roughness_mismatches=',mismatch,' quiet_fraction=',quiet/count,' relief_fraction=',marked/count)
 quit()
