
realms={ }

local c_air = minetest.get_content_id("air")
local c_stone = minetest.get_content_id("default:stone")
local c_dirt = minetest.get_content_id("default:dirt")
local c_dirt_grass = minetest.get_content_id("default:dirt_with_grass")

realms.dflt_biome={
	name="Crystal",
	node_top=c_dirt,
	node_filler=c_dirt_grass,
	dec=nil
	}

--node_dust = "default:snow",
--node_top = "default:dirt_with_snow",
--depth_top = 1,
--node_filler = "default:permafrost",
--depth_filler = 3,
--node_stone = "default:bluestone",


realm={}

--note that these are global
realms.rmg={}  --realms map gen
realms.rmf={}  --realms map function
realms.noise={} --noise (so you can reuse the same noise or change it easily)
realms.biome={} --where registered biomes are stored.  Remember, registerd biomes do nothing unless included in a biome map
realms.biomemap={}



--realms map generator
--********************************
function realms.register_mapgen(name, func)
	realms.rmg[name]=func
	minetest.log("realms-> rmg registered for: "..name)
end --register_mapgen



--realms map function
--********************************
function realms.register_mapfunc(name, func)
	realms.rmf[name]=func
	minetest.log("realms-> rmf registered for: "..name)
end --register_mapfunc


--realms noise
--********************************
function realms.register_noise(name, noise)
	--store the special seed for this noise based on the noise name
	--if the user passes a seed, we will add it to this nameseed
	--that way ONE seed can be passed and used for multiple noises without giving them all the same seed
	local nameseed=0
	for i=1,string.len(name) do
		nameseed=nameseed+i*string.byte(name,i)
	end --for
	noise.nameseed=nameseed
	realms.noise[name]=noise
	minetest.log("realms-> noise registered for: "..name)
end --register_noise


--call this function passing a noise parameter (usually parms.noisename)
--and a default noise name.  The function will return the default noise if parm_noise is blank.
--if you pass seed, the noise.seed will be set to that
--this just makes it simpler and more intuitive to get your noise
--********************************
function realms.get_noise(noisename_in, default_noise, seed)
	local noisename
	--if parm_noise~=nil and parm_noise~="" then noisename=parms.noisetop
	if parm_noise~=nil and parm_noise~="" then noisename=parms_noise
	else noisename=default_noise
	end --if parm_noise
	--minetest.log("realms.init-> noisename="..noisename)
	local noise=realms.noise[noisename]
	if seed~=nil then
		--minetest.log("get_noise-> bfr "..noisename.." seed="..noise.seed)
		noise.seed=noise.nameseed+tonumber(seed)
		--minetest.log("get_noise-> aft "..noisename.." seed="..noise.seed)
	end --if seed
	return noise
end --get_noise


--********************************
function realms.read_realms_config()
	minetest.log("realms-> reading realms config file")
	realm.count=0
	local p
	--first we look to see if there is a realms.conf file in the world path
	local file = io.open(minetest.get_worldpath().."/realms.conf", "r")
	--if its not in the worldpath, try for the modpath
	if file then
		minetest.log("realms-> loading realms.config from worldpath:")
	else
		file = io.open(minetest.get_modpath("realms").."/realms.conf", "r")
		if file then minetest.log("realms-> loading realms.conf from modpath")
		else minetest.log("realms-> unable to find realms file in worldpath or modpath.  This is bad")
		end --if file (modpath)
	end --if file (worldpath)
	if file then
		for str in file:lines() do
			p=string.find(str,"|")
			if p~=nil then --we found a vertical bar, this is an actual entry
				realm.count=realm.count+1
				local r=realm.count
				realm[r]={}
				minetest.log("realms-> count="..realm.count.." str="..str)
				--realm[r].rmg,p=tst,p=luautils.next_field(str,"|",1)  --for some strange reason THIS wont work
				local hld,p=luautils.next_field(str,"|",1,"trim")  --but this works fine
				realm[r].rmg=hld
				realm[r].parms={}
				local mapseed = minetest.get_mapgen_setting("seed") --this is how we get the mapgen seed
				--lua numbers are double-precision floating-point which can only handle numbers up to 100,000,000,000,000
				--but the seed we got back is 20 characters!  We dont really need that much randomness anyway, so we are
				--going to just take the first 13 chars, and turn it into a number, so we can do multiplication and addition to it
				mapseed=tonumber(string.sub(mapseed,1,13))
				--multiplying by the realm number should give us a unique seed for each realm that can be used in noise etc
				--since we cut 13 chars from the mapseed, even realm[1] seed would should be different from the map seed
				realm[r].parms.realm_seed=mapseed*r
				realm[r].parms.realm_minp={}
				realm[r].parms.realm_minp.x, p=luautils.next_field(str,"|",p,"trim","num")
				realm[r].parms.realm_minp.y, p=luautils.next_field(str,"|",p,"trim","num")
				realm[r].parms.realm_minp.z, p=luautils.next_field(str,"|",p,"trim","num")
				realm[r].parms.realm_maxp={}
				realm[r].parms.realm_maxp.x, p=luautils.next_field(str,"|",p,"trim","num")
				realm[r].parms.realm_maxp.y, p=luautils.next_field(str,"|",p,"trim","num")
				realm[r].parms.realm_maxp.z, p=luautils.next_field(str,"|",p,"trim","num")
				realm[r].parms.sealevel, p=luautils.next_field(str,"|",p,"trim","num")
				realm[r].parms.biomefunc, p=luautils.next_field(str,"|",p,"trim","str")
				if realm[r].parms.biomefunc=="" then realm[r].parms.biomefunc=nil end
				local misc
				local var
				local val
				--now we are going to loop through any OTHER flags/variables user set
				while p~=nil do
					misc, p=luautils.next_field(str,"|",p,"trim","str")
					local peq=string.find(misc,"=")
					if peq~=nil then --found var=value
						var=luautils.trim(string.sub(misc,1,peq-1)) --var is everything to the left of the =
						val=luautils.trim(string.sub(misc,peq+1)) --val is everything to the right of the =
						if tonumber(val)~=nil then val=tonumber(val) end  --if the string is numeric, turn it into a number
						realm[r].parms[var]=val
					else realm[r].parms[misc]=true --if no equals found, then treat it as a flag and set true
					end --if peq~=nil
				end --while p~=nil
				minetest.log("realms->   r="..r.." minp="..luautils.pos_to_str(realm[r].parms.realm_minp)..
						" maxp="..luautils.pos_to_str(realm[r].parms.realm_maxp).." sealevel="..realm[r].parms.sealevel)
			end --if p~=nil
		end --for str
		minetest.log("realms-> all realms loaded, count="..realm.count)
	end --if file
end --read_realm_config()



--********************************
function realms.decorate(x,y,z, biome, parms)
	local dec=biome.dec
	--minetest.log("  realms.decorate-> "..luautils.pos_to_str_xyz(x,y,z).." biome="..biome.name)
	if dec==nil then return end --no decorations!
	local area=parms.area
	local data=parms.data
	local d=1
	local r=math.random()*100
	--minetest.log("    r="..r)
	--we will loop until we hit the end of the list, or an entry whose chancebot is <= r
	--so when we exit we will be in one of these conditions
	--dec[d]==nil (this biome had no decorations)
	--r>=dec[d].chancetop (chance was too high, no decoration selected)
	--r<dec[d].chancetop (d is the decoration that was selected)
	while (dec[d]~=nil) and (r<dec[d].chancebot) do
		--minetest.log("      d="..d.." chancetop="..luautils.var_or_nil(dec[d].chancetop).." chancebot="..luautils.var_or_nil(dec[d].chancebot))
		d=d+1
		end
	--minetest.log("      d="..d.." chancetop="..luautils.var_or_nil(dec[d].chancetop).." chancebot="..luautils.var_or_nil(dec[d].chancebot))
	if (dec[d]~=nil) and (r<dec[d].chancetop) then
		--decorate
		--minetest.log("      hit d="..d.." chancetop="..luautils.var_or_nil(dec[d].chancetop).." chancebot="..luautils.var_or_nil(dec[d].chancebot))
		if dec[d].node~=nil then
			luautils.place_node(x,y,z,area,data,dec[d].node)
			if dec[d].height~=nil then
				local height_max=dec[d].height_max
				if height_max==nil then height_max=dec[d].height end
				local r=math.random(dec[d].height,height_max)
				--minetest.log("heighttest-> height="..dec[d].height.." height_max="..height_max.." r="..r)
				for i=2,r do --start at 2 because we already placed 1
					--minetest.log(" i="..i.." y-i+1="..(y-i)+1)
					luautils.place_node(x,y+i-1,z,area,data,dec[d].node)
				end --for
			end --if dec[d].node.height
		elseif dec[d].func~=nil then
			dec[d].func(x, y, z, area, data)
		elseif dec[d].schematic~=nil then
			--minetest.log("  realms.decorate-> schematic "..luautils.pos_to_str_xyz(x,y,z).." biome="..biome.name)
			--luautils.place_node(x,y+1,z,area,data,c_mese)
			--minetest.place_schematic({x=x,y=y,z=z}, dec[d].schema, "random", nil, true)
			--minetest.place_schematic_on_vmanip(parms.vm,{x=x,y=y,z=z}, dec[d].schema, "random", nil, true)
			--can't add schematics to the area properly, so they get added to the parms.mts table, then placed at the end just before the vm is saved
			--I'm using offset instead of center so I dont have to worry about whether the schematic is a table or mts file
			local px=x
			local py=y
			local pz=z
			if dec[d].offset_x ~= nil then px=px+dec[d].offset_x end
			if dec[d].offset_y ~= nil then py=py+dec[d].offset_y end
			if dec[d].offset_z ~= nil then pz=pz+dec[d].offset_z end
			--I dont know how to send flags for mts file schematics, flags dont seem to be working well for me anyway
			table.insert(parms.mts,{{x=px,y=py,z=pz},dec[d].schematic})
		end --if dec[d].node~=nil
	end --if (dec[d]~=nil)

	--minetest.log("  realms.decorate-> "..luautils.pos_to_str_xyz(x,y,z).." biome="..biome.name.." r="..r.." d="..d)
end --decorate




--just allows for error checking and for passing a content id
--********************************
function realms.get_content_id(nodename)
	if nodename==nil or nodename=="" then return nil
	--if you sent a number, assume that is the correct content id
	elseif type(nodename)=="number" then return nodename
	else return minetest.get_content_id(nodename)
	end --if
end --realms.get_content_id



--********************************
function realms.register_biome(biome)
	if realms.biome[biome.name]~=nil then
		minetest.log("realms.register_biome-> ***WARNING!!!*** duplicate biome being registered!  biome.name="..biome.name)
	end
	realms.biome[biome.name]=biome

	--set defaults
	if biome.depth_top==nil then biome.depth_top=1 end
	if biome.node_filler==nil then biome.node_filler="default:dirt" end
	if biome.depth_filler==nil then biome.depth_filler=3 end
	if biome.node_stone==nil then biome.node_stone="default:stone" end


	--turn the node names into node numbers
	--minetest.log("*** biome.name="..biome.name)
	biome.node_dust = realms.get_content_id(biome.node_dust)
	biome.node_top = realms.get_content_id(biome.node_top)
	biome.node_filler = realms.get_content_id(biome.node_filler)
	biome.node_stone = realms.get_content_id(biome.node_stone)
	biome.node_water_top = realms.get_content_id(biome.node_water_top)
	biome.node_riverbed = realms.get_content_id(biome.node_riverbed)
	--will have to do the same thing for the dec.node entries, but we do that below

	--now deal with the decorations (this is different from the way minetest does its biomes)
	local d=1
	if biome.dec~=nil then --there are decorations!
		--# gets the length of an array
		--putting it in biome.dec.max is probably not really needed, but I find it easy to use and understand
		biome.dec.max=#biome.dec
		local chancetop=0
		local chancebot=0
		--loop BACKWARDS from last decoration to first setting our chances.
		--the point here is that we dont want to roll each chance individually.  We want to roll ONE chance,
		--and then determine which decoration, if any, was selected.  So this process sets up the chancetop and chancebot
		--for each dec element so that we can easily (and quickly) go through them when decorating.
		--example:  dec[1].chance=3 dec[2].chance=5 dec 3.chance=2
		--after this runs
		--dec[1].chancebot=7  dec[1].chancetop=9
		--dec[2].chancebot=2  dec[2].chancetop=7
		--dec[3].chancebot=0  dec[3].chancetop=2
		for d=biome.dec.max, 1, -1 do
			chancebot=chancetop
			chancetop=chancetop+biome.dec[d].chance
			biome.dec[d].chancetop=chancetop
			biome.dec[d].chancebot=chancebot
			--turn node entries from strings into numbers
			biome.dec[d].node=realms.get_content_id(biome.dec[d].node) --will return nil if passed nil
		end --for d
		--this is the default function for realms defined biomes, no need to have to specify it every time
		if biome.decorate==nil then biome.decorate=realms.decorate end
	end --if biome.dec~=nil
	minetest.log("realms-> biome registered for: "..biome.name)
end --register_biome



--********************************
function realms.voronoi_sort(a,b) 
	if a.dist==b.dist and a.y_min~=nil and b.y_min~=nil then return a.y_min<b.y_min
	else return a.dist<b.dist
	end --if
end --realms.voronoi_sort 



realms.vboxsz=20
--********************************
function realms.register_biomemap(biomemap)
	--minetest.log("realms.register_biomemap "..biomemap.name)
	if realms.biomemap[biomemap.name]~=nil then
		minetest.log("realms.register_biomemap-> ***WARNING!!!*** duplicate biome map being registered!  biomemap.name="..biomemap.name)
	end
	realms.biomemap[biomemap.name]=biomemap
	if biomemap.typ=="VORONOI" then
		--voronoi diagrams have some nice advantages
		--BUT, I dont know of any simple solution for finding the closest point in a list
		--so, I'm cheating.  We split the voronoi graph into lots of little boxes, calculate
		--the distance to every heat,humid point in the list FROM THE CENTER OF THE BOX
		--and then store that in a 2d array.  
		--now, when we get our noise, we just calculate which box the noise point is in, and
		--then use the list calculated from the center of that box.  It will not be completely
		--accurate, of course, but it should be good enough, and a lot faster than brute force
		biomemap.voronoi={}
		local vboxsz=realms.vboxsz
		--minetest.log("voronoi -> vboxsz="..vboxsz)
		for heat=0,vboxsz-1 do
			biomemap.voronoi[heat]={}
			for humid=0,vboxsz-1 do
				biomemap.voronoi[heat][humid]={}
				local cx=(heat/vboxsz)+(1/(vboxsz*2))
				local cz=(humid/vboxsz)+(1/(vboxsz*2))
				--minetest.log("voronoi-> heat="..heat.." humid="..humid.." cx="..cx.." cz="..cz)
				for i,v in ipairs(biomemap.list) do
					--v=biomemap which contains v.biome, v.heat_point, v_humidity_point
					--this is just a temporary place to store distance, it will be disposed of later
					v.biome.dist=luautils.distance2d(cx,cz, v.heat_point/100,v.humidity_point/100)
					--minetest.log("voronoi->     distance="..v.biome.dist.." to "..v.biome.name.." ("..v.heat_point..","..v.humidity_point..")")
					table.insert(biomemap.voronoi[heat][humid], v.biome) --we insert the actual biome not the biomemap
					--minetest.log("     "..v.biome.dist.."  "..v.biome.name)
				end --for biommap.list
			--now biomemap.voronoi[heat][humid] is a list of all the biomes in the biomemap, with dist
			--we need to sort them.
			table.sort(biomemap.voronoi[heat][humid], realms.voronoi_sort) 
			if biomemap.voronoi[heat][humid][1].count==nil then biomemap.voronoi[heat][humid][1].count=1
			else biomemap.voronoi[heat][humid][1].count=biomemap.voronoi[heat][humid][1].count+1
			end
			local b1=biomemap.voronoi[heat][humid][1]
			--minetest.log("voronoi["..heat.."]["..humid.."][1] -> dist="..b1.dist.." count="..b1.count.." : "..b1.name)
			--minetest.log("-----after sort")
			--for i,v in ipairs(biomemap.voronoi[heat][humid]) do minetest.log("     "..v.dist.."  "..v.name) end
			end --for humid		
		end --for heat
		--now, dispose of those dist variables you put into the biome so that no one thinks they have meaning.
		for i,v in ipairs(biomemap.list) do 
			v.biome.dist=nil 
			--minetest.log("voronoi analysis-> "..v.biome.count.." : "..v.biome.name)
			local c=v.biome.count
			if c==nil then c=0 end
			minetest.log("voronoi analysis-> "..c.." : "..v.biome.name)
			v.biome.count=nil
		end
	end --if voronoi
	minetest.log("realms-> biomemap registered for: "..biomemap.name)
end --register_biomemap






--********************************
function realms.randomize_depth(depth,variation,noise)
	if depth<3 then return depth
	else 
		local d=depth-(depth*variation)+(depth*variation*math.abs(noise))
		return d
	end--if depth
end --reandomize_depth
--[[
function realms.randomize_depth(depth,variation,noise,x,z,minp,chunk_size)
	if depth<3 then return depth
	else 
		local nixz=luautils.xzcoords_to_flat(x,z, minp, chunk_size)
		--minetest.log("randomize_depth-> depth="..depth.." variation="..variation.." noise="..luautils.var_or_nil(noise))
		--return depth-(depth*variation)+(depth*variation*math.abs(noise[nixz]))
		local d=depth-(depth*variation)+(depth*variation*math.abs(noise[nixz]))
		--minetest.log("randomize_depth-> depth="..depth.." variation="..variation.." nixz="..nixz.." noise="..noise[nixz].." d="..d)
		return d
	end--if depth
end --reandomize_depth
]]






--********************************
function realms.gen_realms(chunk_minp, chunk_maxp, seed)
	--eventually, this should run off of an array loaded from a file
	--every rmg (realm terrain generator) should register with a string for a name, and a function
	--the realm params will be loaded from a table
	local r=0
	local doit=false
	repeat
		r=r+1
		if luautils.check_overlap(realm[r].parms.realm_minp, realm[r].parms.realm_maxp, chunk_minp,chunk_maxp)==true then doit=true end
	until r==realm.count or doit==true
	if doit==false then return end --dont waste cpu

	--This actually initializes the LVM.  Since realms allows multiple overlapping
	--map gens to run, we can save cpu by getting the vm once at the begining,
	--passing it to each rmg (realms map gen) as it runs, and saving after
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	local mts = {} --mts array stores schematics
	--add a schematic to this table with: table.insert(parms.mts,{pos,schematic})  (shouldnt matter if table or file, but dont forget the position!)
	--the schematics will be written to the chunk after all other manipulation is done
	--we do it this way because minetest.place_schematic writes to the map, not the vm area, so it gets messed up
	--when the vm is saved after all the realms run.
	--and place_schematic_vmanip does nothing if you are writing to the area, it has to be run after 'set data' and before any of: 'set lighting', 'calc lighting', 'write to map'.
	--https://minetest.org/forum/viewtopic.php?f=47&t=4668&start=2340
	--idea for using table from https://forum.minetest.net/viewtopic.php?f=47&t=18259

	--share is used to pass data between rmgs working on the same chunk
	local share={}
	--r already equals one that matches, so start there
	--could just do the match here automatically and skip the overlap check, then start at r+1?
	local rstart=r
	for r=rstart,realm.count,1 do
		local parms=realm[r].parms
		if luautils.check_overlap(parms.realm_minp, parms.realm_maxp, chunk_minp,chunk_maxp)==true then
			--minetest.log("realms-> gen_realms r="..r.." rmg="..luautils.var_or_nil(realm[r].rmg)..
			--		" realm minp="..luautils.pos_to_str(parms.realm_minp).." maxp="..luautils.pos_to_str(parms.realm_maxp))
			--minetest.log("     sealevel="..parms.sealevel.." chunk minp="..luautils.pos_to_str(chunk_minp).." maxp="..luautils.pos_to_str(chunk_maxp))

			--rmg[realm[r].rmg](realm[r].parms.realm_minp,realm[r].parms.realm_maxp, realm[r].parms.sealevel, chunk_minp,chunk_maxp, 0)
			parms.chunk_minp=chunk_minp
			parms.chunk_maxp=chunk_maxp
			parms.isect_minp, parms.isect_maxp = luautils.box_intersection(parms.realm_minp,parms.realm_maxp, parms.chunk_minp,parms.chunk_maxp)
			parms.isectsize2d = luautils.box_sizexz(parms.isect_minp,parms.isect_maxp)
			parms.isectsize3d = luautils.box_size(parms.isect_minp,parms.isect_maxp)
			parms.minposxz = {x=parms.isect_minp.x, y=parms.isect_minp.z}
			parms.share=share
			parms.area=area
			parms.data=data
			parms.vm=vm  --I dont know if the map gen needs this, but just in case, there it is.
			parms.mts=mts --for storing schematics to be written before vm is saved to map
			parms.chunk_seed=seed --the seed that was passed to realms for this chunk
			--minetest.log("realms-> r="..r)
			minetest.log(">>>realms-> gen_realms r="..r.." rmg="..luautils.var_or_nil(realm[r].rmg).." isect "..luautils.pos_to_str(parms.isect_minp).."-"..luautils.pos_to_str(parms.isect_maxp))
			realms.rmg[realm[r].rmg](parms)
			if parms.area~=area then minetest.log("***realms.init-> WARNING parms.area~=area!!!") end
			share=parms.share --save share to be used in next parms (user might have changed pointer)
		end --if overlap
	end--for

	--Wrap things up and write back to map, send data back to voxelmanip
	--(by saving here we avoid multiple save and pulls in overlapping realm map gens)
	minetest.log("---realms-> saving area "..luautils.range_to_str(chunk_minp,chunk_maxp))
	vm:set_data(data)
	--apply any schematics that were set (see comments above where parms.mts is defined)
	--generator should have placed schematics using: table.insert(parms.mts,{pos,schematic})
	--now we loop through them and know that mts[i][i]=pos and mts[i][2]=schematic
	--need to modify to let user specify is placement should be random or not.
	for i = 1, #mts do
		minetest.place_schematic_on_vmanip(vm, mts[i][1], mts[i][2], "random", nil, true)  --true means force replace other nodes
	end

	--calc lighting
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	--write it to world
	vm:write_to_map(data)

end -- gen_realms

dofile(minetest.get_modpath("realms").."/realms_map_generators/tg_layer_barrier.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/tg_flatland.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/tg_very_simple.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/tg_with_mountains.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bg_basic_biomes.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bf_basic_biomes.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/tg_caves.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bf_odd_biomes.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/tg_stupid_islands.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bf_generic.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bd_basic_biomes.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bd_odd_biomes.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bm_basic_biomes.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bm_mixed_biomes.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bd_default_biomes.lua")
dofile(minetest.get_modpath("realms").."/realms_map_generators/bm_default_biomes.lua")

minetest.register_on_generated(realms.gen_realms)
realms.read_realms_config()




