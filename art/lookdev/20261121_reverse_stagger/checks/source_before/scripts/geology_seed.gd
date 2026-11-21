extends RefCounted
## Fixed integer mixing; independent of the engine's global random stream.
const VERSION:int=1
static func _axis(seed_value:int,salt:int)->float:
 var value:int=seed_value&0xffffffff
 value=(((value^(value>>16))*0x45d9f3b)+salt*69069)&0x7fffffff
 value=((value^(value>>13))*1274126177)&0x7fffffff
 value=value^(value>>16)
 return float(value)/2147483647.0
static func phase(seed_value:int)->Vector3:
 return (Vector3(_axis(seed_value,11),_axis(seed_value,23),_axis(seed_value,47))*2.0-Vector3.ONE)*24.0
