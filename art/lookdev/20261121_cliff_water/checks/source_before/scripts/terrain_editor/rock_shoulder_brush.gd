extends RefCounted
## Normalized geological shoulder brush, with an inward lower return.
## It edits the solid field; it does not create or assemble model instances.
const PLANES=[
 Vector4(0.989343958,0.080762772,0.121144158,0.720000000),
 Vector4(-0.971813096,0.062030623,-0.227445618,0.760000000),
 Vector4(0.250137614,0.300165136,0.920506418,0.720000000),
 Vector4(-0.601777871,-0.100296312,0.792340863,0.640000000),
 Vector4(-0.120180406,0.050075169,-0.991488350,0.700000000),
 Vector4(0.224023759,0.957192424,-0.183292166,0.620000000),
 Vector4(0.151322281,-0.958374446,0.242115650,0.750000000),
 Vector4(0.029935707,-0.848178373,0.528864162,0.400000000),
 Vector4(0.678306349,0.548630135,0.488779575,0.900000000),
 Vector4(-0.451219943,0.802168788,0.391057284,0.850000000),
]
static func distance(p:Vector3)->float:
 p.y/=1.55
 p+=Vector3(sin(p.y*2.3+p.z*.7),sin(p.z*2.1-p.x*.6),sin(p.x*2.2+p.y*.6))*.025
 var result:=-INF
 for plane:Vector4 in PLANES:result=maxf(result,p.dot(Vector3(plane.x,plane.y,plane.z))-plane.w)
 return result
