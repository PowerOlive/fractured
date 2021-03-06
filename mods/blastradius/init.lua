--- Blast Radius

---
--- constants
---

local blastrad_radius=100              --how wide should the blast radius be around 0,0
--this percentage of the outer edge of the blast radius will be scattered with blast material
--instead of all blast material.  so a scatter of 0.25 means the last 25% of the blast
--radius will gradually become less and less blast material
local blastrad_scatter=0.25            --percentage of blastrad to scatter instead of solid
local blastrad_steps=0.30              --percentage of blastrad to start steping up or down to natural height
local blastrad_top=200                 --don't bother blasting higher than this
local blastrad_surface=0               --the blast radius surface  (This is where to START, steps will change it)
local blastrad_deep=3                  --how deep to change existing material
					                             --  so once we find or create a surface, we will change this far down below it
local blastrad_bot=-20                 --don't bother blasting lower than this.


--caclulated constants
local blastrad_noscatter=1-blastrad_scatter  --no scatter within this percentage
local blastrad_steprad=blastrad_radius*(1-blastrad_steps)  --the width of each step
local blastrad_changebot=blastrad_surface-blastrad_deep    --the change bottom (based on where the surface is)



--grab content IDs -- You need these to efficiently access and set node data.  get_node() works, but is far slower
local c_blastmat = minetest.get_content_id("fractured:dry_dirt")
local c_scorchedtree = minetest.get_content_id("fractured:scorched_tree")
local c_air = minetest.get_content_id("air")
local c_ice = minetest.get_content_id("default:ice")
local c_watersource = minetest.get_content_id("default:water_source")


--what material to use for the blast
--for example, replace trees with scorched tree
function blast_replace(x,y,z, cid)
	local rplc=c_blastmat  --default
	--local node=minetest.get_node({x=x,y=y,z=z})
	local rnode=minetest.registered_nodes[minetest.get_node({x=x,y=y,z=z}).name]

	if rnode.is_ground_content
			or cid==c_ice
			or cid==c_watersource
			or cid==c_blastmat
			then
		rplc=c_blastmat
	elseif rnode.groups.tree~=nil and rnode.groups.tree==1 then
		rplc=c_scorchedtree
	elseif rnode.groups.leaves~=nil and rnode.groups.leaves==1 then
		rplc=c_air
	else
		local t=rnode.groups.tree
		if t==nil then t="nil" end
		local l=rnode.groups.leaves
		if l==nil then l="nil" end
		minetest.log("blastradius-> unidentified material: "..rnode.name.. " rnode.tree="..t.." rnode.leaves="..l)
		--minetest.log("balstradius-> rnode="..dump(rnode))
		rplc=c_air
	end --if
	return rplc
end




function generate_blastradius(minp, maxp, seed)
	--dont bother if we are not near the blast zone
	if minp.x > blastrad_radius or maxp.x < -blastrad_radius or
		 minp.y > blastrad_top or maxp.y < blastrad_bot or
		 minp.z > blastrad_radius or maxp.z < -blastrad_radius then
		 return --quit; otherwise, you'd have wasted resources
	end

	--easy reference to commonly used values
	local t1 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local ymax=maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local ymin=minp.y
	local z0 = minp.z

	--no reason to scan outside the y range we are changing.
		if y0 < blastrad_bot then
			y0 = blastrad_bot
		end
		if y1 > blastrad_top then
			y1 = blastrad_top
		end

	--minetest.log("[blast_gen] chunk minp ("..x0.." "..y0.." "..z0..")") --tell people you are generating a chunk

	--This actually initializes the LVM
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()

	local changed=false

	for z = z0, z1 do --
		for x = x0, x1 do --
			local dist= math.floor(math.sqrt(x^2+z^2))  --since we know the center is 0,0
			if dist <= blastrad_radius then -- x and z inside blast circle radius

				local step=0
				if dist > blastrad_steprad then  --if we are past the radius where the steps start
					step = dist - blastrad_steprad --so now step=how many nodes we are past the stepradius where the steps start
				end
				local local_surface_top = blastrad_surface+step
				local local_surface_bot = blastrad_surface-step
				-- local_surface_top and _bot are the RANGE in which the surface must be.  anything above local_surface_top must be
				-- trimmed down to local_surface_top, and anything below local_surface_bot must be built up to it.  But if the surface
				-- is between those two points it is ok.

				-- when ignore=true we wont change the material so that the blast effect looks like it is fading out as it gets further from the center
				local ignore = false
				if dist/blastrad_radius >= blastrad_noscatter and math.random() < (((dist/blastrad_radius)-blastrad_noscatter)/blastrad_scatter) then
					ignore = true
				end

				local local_changebot=blastrad_changebot

				for y = y1, y0, -1 do
					local vi = area:index(x, y, z) -- This accesses the node at a given position
					--anything above local_surface_top and below blastrad_top should be changed to air
					if y > local_surface_top and y <= blastrad_top and data[vi] ~= c_air then
						data[vi] = c_air
--						if x==48 and y==1 and z==-14 then minetest.log("blastradius-> changed ("..x..","..y..","..z..") to air") end
						changed = true
					--if not ignore,
					--and we find material between local_surface_bot and local_surface_top,
					--or we are below local_surface_bot (but not below blastrad_bot because we dont change anything below that)
					elseif (ignore == false) and
								 (y > local_surface_bot and y <= local_surface_top and data[vi] ~= c_air) or
								 (y <= local_surface_bot and y >= blastrad_bot ) then
						--so now that we have determined that we are either: between local bot/top and not air, or below local bot:
						--if its air, and we are above local_changebot, replace it
						if data[vi] == c_air or y >= local_changebot then
							data[vi]=blast_replace(x,y,z, data[vi])
							changed = true
							--blastrad_changebot is blastrad_surface(starting surface)-blastrad_deep(how deep we want the change to go)
							--we set local_changebot=blastrad_changebot before the y loop
							--if they are STILL equal, (meaning this is the first time we have changed anything for this y)
							--then move the local_changebot to be the current y minus how deep we want the change to go-1 (because we just changed this)
							if local_changebot == blastrad_changebot then
								local_changebot = y - (blastrad_deep-1)
							end
							--so what happens when y=0 so that local_changebot==blastrad_changebot even after y-(blastrad_deep-1) ???
						end -- change below
					end --blast
					--blast area if
				end -- for y
			end -- if in blast area
		end -- end 'x' loop
	end -- end 'z' loop

	if changed==true then
--		minetest.log("blastradius-> saving chunk minp="..minetest.pos_to_string(minp).." maxp="..minetest.pos_to_string(maxp).." node(48,1,-14)="..minetest.get_node({x=48,y=1,z=-14}).name)
--		if luautils.xyz_in_box(48,1,-14, minp,maxp) then
--			local vi = area:index(48,1,-14) -- This accesses the node at a given position
--			minetest.log("blastradius-> save (48,1,-14) cid="..data[vi].." node="..minetest.get_node({x=48,y=1,z=-14}).name)
--		end --debug if
		-- Wrap things up and write back to map
		--send data back to voxelmanip
		vm:set_data(data)
		--calc lighting
		vm:set_lighting({day=0, night=0})
		vm:calc_lighting()
		--write it to world
		vm:write_to_map(data)
		--print(">>>saved")
	end --if changed write to map

	local chugent = math.ceil((os.clock() - t1) * 1000) --grab how long it took
	minetest.log("[blast_gen] "..chugent.." ms") --tell people how long
end



minetest.register_on_generated(generate_blastradius) -- register_on_generated blast radius








