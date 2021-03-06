pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
--       'the last crane'
-- -------------------------
--      2017  @headjump
--            for ld39

-- --[config]--
version="0.1"
--debug=true
st={}--entire game state
t_consumable=0--entity tags
function _init() ngn_scene(sc_start()) end

function sc_start()
 local blink_cnt=cntdwn(30,true)
 return {
  grav={x=0,y=.12},
  upd=function(st)
   if(btnp(4) or btnp(5)) then ngn_scene(sc_game(1)) end
   blink_cnt.upd()
   if(rnd(1)<.4)then
    ngn_part(
     rnd(14*4)+36,24,-- x,y
     0,1,-- sx,sy
     .3,14,-- grav,lifetime
     {1},-- sizes
     {10,9,2},-- cols
     .9) -- acc (default=1)
   end
  end,
  drw=function(st)
   cls()
   print("the last crane",36,20,9)
   print("press � to start",30,40,cond(blink_cnt.val<=15,5,6))
   spr(cond(flr(blink_cnt.val/5)%2==0,1,3),56,94,2,2)
   print(" prototype "..version,34,110,8)
  end
 }
end

function sc_gameover()
 return {
  blink=0,
  wait_till_btn=cntdwn(45,false),
  blink_tgl=cntdwn(15,true),
  blink_st=0,
  upd=function(st)
   if(st.wait_till_btn.upd())then 
    if(btnp(4) or btnp(5))then ngn_scene(sc_start()) return end
    if(st.blink_tgl.upd())then st.blink_st= not st.blink_st end
   end
  end,
  drw=function(st)
   cls()
   print("you ran out of energy",22,20,8)
   if(st.wait_till_btn.over)then
    print("press x to retry",30,40,cond(st.blink_st,5,6))
    end
  end
 }
end

function ent_consumer()
 local dispatch_every=10
 local me
 me={
  layer=3,
  ents={},
  wait_till_dispatch=dispatch_every,--fillup while consuming
  busy=false,
  add=function(ent)
   local to_consuming=ent.to_consuming()
   to_consuming.bind_to_claw = true
   add(me.ents,to_consuming)
   ngn_rem(ent)
  end,
  late_upd=function(e,st)
   local cr=st.crane
   local cl=st.claw
   local generating_energy=false
   e.busy=false
   for ent in all(e.ents) do
    e.busy=true
    if(not st.claw)then ent.bind_to_claw=false end    
    if(ent.energy <= 0)then del(e.ents,ent) end
    if(not ent.bind_to_claw)then
     generating_energy=true
     ent.energy-=timed(1)
     st.battery.amount+=timed(1)
    end
   end
   e.generating_energy=generating_energy--need it in tutorial
   if(generating_energy)then
    if(rnd(1)>.65)then
     ngn_part(
      st.crane.x+1+rnd(6),st.crane.y-4,-- x,y
      st.crane.spd,1+rnd(.5),-- sx,sy
      1.2,6,-- grav,lifetime
      {2,1,1},-- sizes
      {11,3,1},-- cols
      1,true) -- acc (default=1),draw in front
    end
    e.wait_till_dispatch-=timed(1)
    if(e.wait_till_dispatch<=0)then
     e.wait_till_dispatch=dispatch_every
     ngn_add(ent_energy_fillup(st.crane,11,7))
    end
   end
  end,
  drw=function(e)
   local at_crane=st.crane.y-8+2
   local consuming=false--if sth is at crane
   local x
   local y
   for ent in all(e.ents) do
    x=st.crane.x+3
    y=ent.bind_to_claw and st.claw and st.claw.y or st.crane.y-8+2
    if(y==at_crane)then consuming=true; ent.bind_to_claw=false end
    ent.drw(ent,ent.bind_to_claw,x,y)
   end
  end
 }
 return me
end

function ent_claw(crane)
 return {
  x=crane.x,
  y=crane.y-8+2,
  hitbox={-4,1,12,7},
  spd=-.1,
  layer=3,
  scale=1,
  go_down=false,
  ani_state=0,
  lifetime=0,
  late_upd=function(e)
   if(not e.tw)then 
    -- animate claw larger
    e.tw=tween(e,.6,{scale=11},ease_out)
   else    
    if(e.tw.upd() and e.ani_state==0)then
     --animate claw smaller again, till default size
     e.tw=tween(e,.5,{scale=8},ease_back)
     e.ani_state=1
    end
   end
   e.x=crane.x
   e.spd=cond(e.go_down, in_range(e.spd+timed(.5),0,14),in_range(e.spd*timed_fac(1.35),-5,0))
   e.y+=timed(e.spd)
   e.lifetime+=timed(1)

   if(not e.go_down)then
    -- hit top
    if e.y<=-2 or fget(mget(flr((e.x+4)/8),flr((e.y)/8)),0) then
     e.go_down=true
     e.spd=2
     for i=0,5 do ngn_part(
      e.x+rnd(16)-4,e.y+2,-- x,y
      rnd(2)-1,rnd(1)+1,-- sx,sy
      1.2,14,-- grav,lifetime
      {2,1,1},-- sizes
      {cond(rnd(1)<.5,13,9),9,5},-- cols
      .9) -- acc (default=1)
     end
    end

    --grab!
    for cons in all(ngn_tagged(t_consumable)) do
     if(ngn_coll(e,cons))then
      e.grabbing=true
      e.go_down=true
      st.consumer.add(cons)
      for i=1,4 do
       ngn_part(
        e.x+1,e.y+6,-- x,y
        rnd(4)-2,rnd(1)-3,-- sx,sy
        1.2,14,-- grav,lifetime
        {2,1,1},-- sizes
        {11,3,5},-- cols
        .9) -- acc (default=1)
      end
     end
    end

   end    

   -- destroy self!
   if e.go_down and e.y>crane.y-8+2 then
    ngn_rem(e)
    st.claw=nil
   end

  end,
  drw=function(e)
   if(e.lifetime<7 or e.go_down)then
    --small
    spr(23,e.x,e.y)
   else
    local dx=e.scale*2
    local dy=8--e.scale
    sspr(7*8,0,16,8,e.x+4-(dx/2),e.y+8-dy,dx,dy)
   end
  end
 }
end

function ent_crane(x,y)
 return {x=x,y=y,layer=3,
  spd=0,dir=1,
  ani_cnt=0,
  ttl_when_no_battery=30,--also reset below!
  dead=false,  
  dead_since=0,
  driving=false,
  upd=function(e,st)
   local slowdown=function() e.spd*=timed_fac(.85) end

   if(e.dead)then e.dead_since+=timed(1) end
   if(not st.claw and not e.dead)then
    -- launch claw
    if((btnp(4) or btnp(5)) and not st.consumer.generating_energy)then
     st.claw=ngn_add(ent_claw(e))
    end
    -- set dir, driving
    if(btnp(0))then e.dir = -1 end
    if(btnp(1))then e.dir = 1 end
    e.driving=(btn(0) or btn(1))
    -- acc or slowdown
    if(btn(0))then e.spd-=timed(.3)
    elseif(btn(1))then e.spd+=timed(.3)
    else slowdown() end
    local max_spd=cond(st.battery.nearly_empty,1,2.5)
    e.spd=in_range(e.spd,-max_spd,max_spd)
   else
    e.driving=false
    slowdown()
   end
   e.x+=e.spd -- move!
   local hit_wall
   e.x,hit_wall=in_range(e.x,12,127-26)
   if(hit_wall)then e.spd=0 end
   e.ani_cnt+=timed(1)
   if(e.ani_cnt>=90)then e.ani_cnt=1 end
   --parts
   if(e.driving and rnd(1)<=cond(hit_wall,.5,.2))then
    ngn_part(
     e.x+3,e.y+9,-- x,y
     -(cond(hit_wall,2,.5)+rnd(10)/10)*e.dir,-rnd(2)-cond(hit_wall,1,0),-- sx,sy
     1.2,14,-- grav,lifetime
     {2,1,1},-- sizes
     {5,1},-- cols
     .9) -- acc (default=1)
   end
   -- battery empty?
   if(st.battery.amount<=0)then
    e.ttl_when_no_battery-=timed(1)
    if(e.ttl_when_no_battery<=0 and not st.claw)then
     e.dead=true
    end
   else e.ttl_when_no_battery=30 end
  end,
  drw=function(e,st)
   if(e.dead)then
    return spr(cond(e.dead_since<15,38,39),e.x,e.y)
   else
    if(not st.claw)then 
     -- rotate wheels when driving
     spr(cond(e.driving and (flr(e.ani_cnt/5)%2==0), 5, 6),e.x,e.y,1,1,e.dir==1)
     if(st.consumer.busy)then
      -- large claw while consuming
      spr(7,e.x-2,e.y-8)
      spr(8,e.x+2,e.y-8)
     else
      -- tiny claw
      spr(23,e.x,e.y-8)
     end
    else
     -- duck to dispatch claw,
     -- then look up
     spr(cond(st.claw.lifetime<10,21,22),e.x,e.y,1,1,e.dir==1)
    end
   end
   -- energy-pipe pixel
   rect(e.x+3,e.y+9,e.x+3,e.y+8,1)
  end
 }
end

function ent_orb(x,y)
 return {
  tag=t_consumable,
  layer=3,
  x=x,y=y,
  to_consuming=function()
   return{    
    ani_tgl=tgl(6),
    energy=50,
    drw=function(e,still_grabbing,x,y)
     local ani=cond(still_grabbing,{14,15},{28,29})
     local sx,sy=spr_pos(ani[e.ani_tgl.val+1])
     local sw=flr(e.energy/50*7)+1
     local offset=(8-sw)/2
     sspr(sx,sy,8,8,x-3+offset,y-3+offset,sw,sw)
     e.ani_tgl.upd()
    end
   }
  end,
  hitbox={1,1,6,6},
  ani=ani({11,12,13},true,10),
  upd=function(e,st)
   e.ani.upd()
  end,
  drw=function(e)
   spr(e.ani.spr,e.x,e.y)
  end
 }
end

function ent_energy(col)
 return {
  x=14*8+2,y=14*8+1,st="left",layer=3,
  late_upd=function(e,st)
   local crane=st.crane
   if(e.x<=crane.x+4)then
    e.st="up"
   end
   if(e.st=="left")then
    e.x-=timed(2.5)
   elseif(e.st=="up")then
    e.x=crane.x+3
    e.y-=timed(.25)
    if(e.y<=crane.y+5)then ngn_rem(e) return end
   end
  end,
  drw=function(e)
   rect(e.x,e.y,cond(e.st=="left",1,0)+e.x,e.y,col)
  end
 }
end

function ent_energy_fillup(crane,col,col_in_bar)
 return {
  x=crane.x+4,y=14*8+1,st="right",layer=3,flashtime=6,
  upd=function(e,st)
   local battery_x=st.battery.bar[1]+st.battery.bar[3]/2
   if(e.st=="right")then
    e.x+=timed(2.5)
    if(e.x>=battery_x-1)then
     e.st="up"
     e.x=battery_x
    end    
   elseif(e.st=="up")then
    e.x=battery_x
    e.y-=timed(.25)
    local bar=st.battery.bar
    local bar_y=bar[2]+bar[4]
    if(e.y<=bar_y)then e.y=bar_y; e.st="flash" end
   elseif(e.st=="flash")then
    e.flashtime-=timed(1)
    if(e.flashtime<=0)then ngn_rem(e); return end    
   end
  end,
  drw=function(e,st)
   if(e.st=="flash")then
    local bar=st.battery.bar
    rect(bar[1],bar[2]+bar[4],bar[1]+bar[3]-1,bar[2]+bar[4],col_in_bar)
   else
    rect(e.x,e.y,cond(e.st=="right",2,0)+e.x,e.y,col)
   end
  end
 }
end

function ent_battery()
 local energy_every=15
 return {
  layer=3,
  lose_energy=true,
  bar={14*8,11*8+6,7,17},
  amount=100.0,
  full=true,
  nearly_empty=false,
  next_energy_in=energy_every,
  ani_cnt=0,
  upd=function(e)
   e.amount=in_range(e.amount-cond(e.lose_energy,timed(.2),0),0,100.0)
   e.full=e.amount>=100.0
   e.nearly_empty=e.amount<=15

   e.ani_cnt+=timed(1)
   if(e.ani_cnt>30) then e.ani_cnt=0 end
   e.next_energy_in-=timed(1)
   if(e.next_energy_in<=0 and e.amount>0)then
    ngn_add(ent_energy(cond(e.nearly_empty,8,11)))
    e.next_energy_in=energy_every
   end
  end,
  drw=function(e)
    local bar=e.bar
    local light={bar[1],bar[2]-7}
    -- blinking light
    if(e.nearly_empty)then
      if(flr(e.ani_cnt/8)%2==0)then rectfill(light[1]-1,light[2]-2,light[1]+1,light[2],8) end
    else
      rect(light[1],light[2],light[1],light[2],11)
    end
    -- energy bar
    if(e.amount>0) then rectfill(bar[1],bar[2]+bar[4],bar[1]+bar[3]-1,bar[2]+bar[4]-bar[4]*min(1,e.amount/100.0),cond(e.nearly_empty,8,11)) end
  end
 }
end

c_none=0
c_after_tut=1
function checkpoint()
 return c_none
end

function director()
 local phase
 local phases
 local orb_dispatcher
 local drw_msg=function(msg,col,oy)
  local x=64-#msg*2; local y=48+(oy or 0);
  print(msg,x,y+1,1)
  print(msg,x,y,col)
 end
 local p_set_battery=function(active)
  return {upd=function(e,st) st.battery.lose_energy=active; return true; end}
 end
 local p_msg=function(msg,col,time)
  local cnt=cntdwn(time)
  return {
   upd=cnt.upd,
   drw=function() drw_msg(msg,col) end
  }
 end
 local p_wait=cntdwn
 local p_tut_move=function(msg,col)
  --show < > arrows next to crane
  local blink_tgl=tgl(10)
  local done_cnt
  return {
   upd=function()
    if(done_cnt)then
     if(done_cnt.upd()) return true
    else 
     blink_tgl.upd()
     if(abs(st.crane.spd)>=1)then done_cnt=cntdwn(15) end
    end
   end,
   drw=function(e,st)
    local cx=st.crane.x; local cy=st.crane.y;
    drw_msg(msg,col)
    if(blink_tgl.val>0)then
     spr(64,cx-12,cy-5)
     spr(64,cx+12,cy-5,1,1,1)
    end
   end
  }
 end
 local p_tut_battery=function(msg,col,time)
  --show arrow to battery
  local blink_tgl=tgl(10)
  local done_cnt=cntdwn(time)
  return {
   upd=function()
    blink_tgl.upd()
    if(done_cnt.upd())then return true end
   end,
   drw=function(e,st)
    local bat=st.battery.bar
    drw_msg(msg,col)
    if(blink_tgl.val>0)then spr(66,bat[1],bat[2]-14) end
   end
  }
 end
 local p_tut_grab=function(msg,col,min_time)
  local min_time_cnt=cntdwn(min_time)
  local was_generating=false
  return {
   upd=function(e,st)
    min_time_cnt.upd()
    if(st.consumer.generating_energy)then was_generating=true end
    return was_generating and min_time_cnt.over
   end,
   drw=function(e,st)
    local target=ngn_tagged(t_consumable)[1]
    if(target)then
     drw_msg(msg,col)
     print("�",target.x,target.y+10)
    end
   end
  }
 end
 local p_tut_fillup=function(msg,col,min_time)
  local blink_tgl=tgl(10)
  local min_time_cnt=cntdwn(min_time)
  local was_full=false
  return {
   upd=function(e,st)
    blink_tgl.upd()
    if(st.battery.full)then was_full=true end
    min_time_cnt.upd()
    return min_time_cnt.over and was_full
   end,
   drw=function(e,st)
    local bat=st.battery.bar
    drw_msg(msg,col)
    if(blink_tgl.val>0)then spr(66,bat[1],bat[2]-14) end
   end
  }
 end
 local p_set_orb_interval=function(int_from,int_to,immediate_dispatch)
  return {upd=function()
   orb_dispatcher.set_interval(int_from,int_to); 
   if(immediate_dispatch)then orb_dispatcher.now() end
   return true; end}
 end
 local __orb_dispatcher=(function()
  local cnt=nil
  local int_from
  local int_to
  local restart=function()
   if(not cnt)then
    cnt=cntdwn(9999)
   end
   cnt.set(rnd(int_to-int_from)+int_from)
  end
  local create_orb=function()
   ngn_add(ent_orb(rnd(8)*13+8,rnd(8)*6+8))
  end

  return {
   set_interval=function(steps_from,steps_to)   
    int_from=steps_from; int_to=steps_to;
    restart()
   end,
   now=function()
    if(cnt)then
     create_orb()
     restart()
    end
   end,
   upd=function()
    if(cnt and cnt.upd())then
     create_orb()
     restart()
    end
   end
  }
 end)()
 orb_dispatcher=__orb_dispatcher
 local leave_after_death=cntdwn(45)

 return {
  layer=4,
  upd=function(e,st)
   if st.crane.dead then 
    if(leave_after_death.upd())then ngn_scene(sc_gameover()) end
   else
    if not phases then
     if(checkpoint()<c_after_tut)then--tutorial phases
      phases={
       {p_set_battery,false},--disable battery!
       {p_wait,20},
       {p_msg,"hello, little crane",7,60},
       {p_wait,20},
       {p_tut_move,"move!",7},
       {p_wait,4},
       {p_msg,"nice!",7,30},
       {p_wait,12},
       {p_msg,"bad news: aliens attack",7,60},
       {p_wait,6},
       {p_set_battery,true},--enable battery!
       {p_set_orb_interval,60,60,true},
       {p_tut_battery,"and your energy runs out",7,120},
       {p_wait,25},
       {p_tut_grab,"grab a green alien",7,20},
       {p_wait,12},
       {p_tut_fillup,"it fills up your energy",7,60}
      }
     else--important stuff that happens through tut
      phases={
       {p_set_orb_interval,60,60,true}
      }
     end
     append(phases,{})
    end--/phase creation
    --create current phase
    if(not phase and #phases>0)then local nxt=phases[1]; phase=nxt[1](nxt[2],nxt[3],nxt[4],nxt[5]) end
    --upd phase and maybe proceed
    if(phase and phase.upd(e,st)) then del(phases,phases[1]); phase=nil end

    orb_dispatcher.upd()
   end
  end,
  drw=function(e,st)
   if(phase and phase.drw)then phase.drw(e,st) end
  end
 }
end

function sc_game(level,easy)
 local crane=ent_crane(60,104)
 local drawmap={ layer=3, drw=function(e) map(0,0,0,0,16,16) end }
 local battery=ent_battery()
 local consumer=ent_consumer()
 local drawrope={ layer=3,
  drw=function(_,st)
   if(st.claw)then
    for i=st.claw.y+8,st.crane.y,8 do spr(24,st.claw.x-1+cond(i%30>15,1,0),i) end
   end
  end}

 return {
  init=function(st)
   foreach({
    drawmap,
    drawrope,
    battery,
    crane,
    consumer,
    director()},ngn_add)
   st.crane=crane;st.battery=battery;st.consumer=consumer;
  end,
  grav={x=0,y=.12}
 }
end


-- ---------------- engine -----
function _update() ngn_upd() end
function _draw() ngn_drw() end

--returns {spr,upd,done} that
--proceeds anim when called
-- script: int array
-- loop: loops when done
-- every: proceed every n calls
function ani(script,loop,every)
  every = every or 6
 local call_cnt = -1
 local ret={spr=1,done=false,flipx=false}
 local frame=1
 ret.spr=script[1]
 ret.upd= function()
  call_cnt+=timed(1)
  if(call_cnt>every)then
   call_cnt=0
   frame+=flr(call_cnt/every) + 1
   ret.done = frame>=#script
   if(frame>#script)then
    if(loop)then frame=1 else frame=#script end
   end
   local sp=script[frame]
   if(sp>=0)then
    ret.spr=sp
    ret.flipx=false
   else
    ret.spr=-sp
    ret.flipx=true
   end
  end
  return ret.done
 end
 return ret
end

-- ngn
------

-- keeps val in range
-- also returns was_clamped?
-- val<min => mim,true
-- val>max => max,true
-- otherwise val,false
function in_range(val,min,max)
 if(val<min) return min,true
 if(val>max) return max,true
 return val,false
end

-- random in range
function ran(min,max)
 return rnd(max-min)+min
end

function cond(cond,v1,v2)
  if(cond)then return v1 end
  return v2
end

-- get valid index in array
-- for item at position given
-- by 'fac' (factor 0..1)
function array_index(cnt,fac)
 return min(cnt,1+flr(cnt*fac))
end

-- object that toggles through some vals
-- @param steps -> after howmany steps to toggle
-- @param num_vals -> how many vals? default: 2
function tgl(steps,num_vals,init)
 init=init or 0
 num_vals=num_vals or 2
 local me
 local step=0
 me={val=init,upd=function()
  step+=timed(1)
  if(step>=steps)then
   me.val+=1
   me.val%=num_vals
   step=0
  end
 end}
 return me
end

function append(target,arr)
 for item in all(arr) do
  add(target,item)
 end
end

-- use upd() each frame to countdown.
-- upd() returns true when countdown is at 0
-- if reset_when_zero the countdown will
--  restart immediately
function cntdwn(steps,reset_when_zero)
 local me
 me={
  val=steps,
  over=false,
  set=function(new_steps,dont_reset) steps=new_steps; if(not dont_reset)then me.val=new_steps; me.over=false end end,
  upd=function()
   me.val-=timed(1)
   if(me.val<=0)then me.val=cond(reset_when_zero,steps,0) me.over=true return true end
   me.over=false
   return false
  end,
  reset=function() me.val=steps end
 }
 return me
end

function spr_pos(spr_index)
 return (spr_index%16)*8,flr(spr_index/16)*8
end

-- create particle
-- x,y
-- sx,sy
-- grav,lifetime
-- sizes
-- cols
-- acc (default=1)
function ngn_part(x,y,sx,sy,grav,lifetime,sizes,cols,acc,draw_in_front)
 if(not st.__part)then
  st.__part=ngn_add({
  parts={},
  upd=function(e)
   e.layer=1--hack to draw twice!
   local new_p={}
   for p in all(e.parts) do
    p.x+=timed(p.sx) p.y+=timed(p.sy)
    p.sx+=p.grav*timed(st.grav.x)
    p.sx*=timed_fac(p.acc)
    p.sy+=p.grav*timed(st.grav.y)
    p.sy*=timed_fac(p.acc)
    p.lifetime-=timed(1)
    if(p.lifetime>=0) add(new_p,p)
   end
   e.parts=new_p
  end,
  layer=1,
  drw=function(e)
   local draw_in_front=e.layer==4
   for p in all(e.parts) do
    if(p.draw_in_front==draw_in_front)then    
     local fac=1-(p.lifetime/p.init_lifetime)
     local sh=p.sizes[array_index(#p.sizes,fac)]/2
     local col=p.cols[array_index(#p.cols,fac)]
     if(sh <=.7)then
      pset(p.x,p.y,col)
     else
      rectfill(p.x-sh,p.y-sh,p.x+sh,p.y+sh,col)
     end
    end
   end
   if(e.layer==1)then e.layer=4 end--hack to draw twice!
  end
  })
 end
 add(st.__part.parts,{
  x=x,y=y,sx=sx or 0,sy=sy or 0,sizes=sizes or {1},grav=grav or 0,
  init_lifetime=lifetime or 20,acc=acc or 1,
  lifetime=lifetime or 20,cols=cols or {0},draw_in_front=draw_in_front or false
 })
end

-- sign of val
-- e.g
--  sign(-5) => -1
--  sugb(3)  => 1
function sign(val)
 if(val<0) return -1
 return 1
end

function ngn_freeze(frames)
 st.freeze=timed(frames or 1)
end

function ngn_clear_freeze()
 del(st,st.freeze)
end

function ngn_shake(from_x,to_x,from_y,to_y,frames)
 st.shake={
  x=0,y=0,cnt=frames or 5,
  upd=function()
   local sh = st.shake
   sh.cnt-=timed(1)
   sh.x=ran(from_x,to_x) sh.y=ran(from_y,to_y) 
   if(sh.cnt<=0) st.shake=nil
  end
 }
end

-- val normalized by timescale
-- timescale 1 => 1/30 sec
function timed(val)
 return st.timescale * val
end

-- factor normalized by timescale
-- timescale 1 => 1/30 sec
function timed_fac(fac)
 return 1-(1-fac)*st.timescale
end

-- creates tweening object
-- -----------------------
-- obj -> tween target
-- sec -> seconds till complete
--          1step = 1/30sec
-- to -> hash w/ target vals
-- returns {
--  upd() -> call every frame
--  done -> boolean completed? 
-- }
function tween(obj,sec,to,ease)
 ease=ease or ease_inout
 local cur=0.0
 local res={perc=0.0}
 local begin={}
 local dist={}
 local steps=sec*30
 for k,v in pairs(to) do begin[k]=obj[k] dist[k]=v-obj[k] end
 res.upd=function()
  if(res.done) return true
  cur+=timed(1)
  if(cur>=steps) cur=steps res.done=true
  local fac=cur/steps
  for k,v in pairs(dist) do
   obj[k]=ease(begin[k],to[k],v,fac)
  end
  res.perc=fac
  return res.done
 end
 return res
end

-- easing
function ease_linear(from,to,dist,fac) return from+dist*fac end
function ease_inout(from,to,dist,fac) fac=fac*fac*(3-2*fac) return from*(1-fac) + to*fac end
function ease_in(from,to,dist,fac) fac=fac*fac return from*(1-fac) + to*fac end
function ease_out(from,to,dist,fac) fac=1-(1-fac)*(1-fac) return from*(1-fac) + to*fac end
function ease_back(from,to,dist,fac) fac-=1 return dist * (fac * fac * (3 * fac + 2) + 1) + from end
function ease_backin(from,to,dist,fac) return ease_back(to,from,-dist,1-fac) end
function ease_bounce(from,to,dist,fac)
 if fac<1/2.75 then
  return dist*(7.5625*fac*fac)+from
 elseif fac<2/2.75 then
  fac-=(1.5/2.75) return dist*(7.5625*fac*fac+0.75)+from
 elseif fac<2.5/2.75 then
  fac-=(2.25/2.75) return dist*(7.5625*fac*fac+0.9375)+from
 end
 fac-=(2.625/2.75)
 return dist*(7.5625*fac*fac+0.984375)+from
end

-- creates object with
-- .upd() and .done
-- that sets 'done=true'
-- when 'sec' are over
function wait(sec)
 local steps=sec*30
 local cur=0.0
 local res={perc=0.0}
 res.upd=function()
  cur+=timed(1)
  if(cur>=steps) res.done=true cur=steps
  if(steps>0)res.perc=cur/steps
  return res.done
 end
 return res
end

-- move 'cur' closer to 'target'
-- by factor, snap_at
-- return => new_val, snapped
function closer(val,target,factor,snap_at)
 if(val==target) return target,true
 factor=factor or .3
 snap_at=snap_at or .005
 val=val+(target-val)*factor
 if(abs(val-target)<=snap_at)then
  return target,true
 end
 return val,false 
end

__ngn_def_hitb={0,0,7,7}
function ngn_coll(e1,e2)
 local h1=e1.hitbox or __ngn_def_hitb
 local h2=e2.hitbox or __ngn_def_hitb
 return e1.x+h1[3]>=e2.x+h2[1] and e1.y+h1[4]>=e2.y+h2[2] and e1.x+h1[1]<e2.x+h2[3] and e1.y+h1[2]<e2.y+h2[4]
end

function ngn_pcoll(x,y,e)
 local h=e.hitbox or __ngn_def_hitb
 return x>=e.x+h[1] and y>=e.y+h[2] and x<=e.x+h[3] and y<=e.y+h[4]
end

__ngn_scene_switched=false --used to prevent running entity updates for old scene

-- scene hooks
-- -----------
-- timescale => 1 = 30fps
-- init(st) => after new menu has been set
-- out(st)  => on change to other scene
-- drw(st)  => before ent{}.drw
-- upd(st)  => before ent{}.upd
-- late_upd(st) => after ent{}.late_upd
function ngn_scene(new_scene)
 __ngn_scene_switched = true
 if st then
  if(st.out) st.out(st)
  local cloned={}
  for e in all(st.ent) do
   add(cloned, e)
  end
  foreach(cloned,ngn_rem)
 end
 if not(new_scene.timescale or new_scene.timescale == 0) then
  new_scene.timescale = 1
 end
 new_scene.ent = new_scene.ent or {}
 new_scene.drw = new_scene.drw or
  function() cls(0) end
 st=new_scene
 if(st.init) st.init(st)
end

-- add entity
-- entity hooks:
-- -------------
-- layer  => draw layer 0..5
-- tag""
-- tags{..}
-- hitbox{l,t,r,b} bounds: x+l,y+t,x+r,y+b 
-- drw(e,e.stp)
-- upd(e,e.stp)
-- late_upd(e,e.stp) => after all ent{}.upd()
function ngn_add(e)
 if(not st.ent) st.ent={}
 add(st.ent,e)
 return e
end

-- get entities with tag
function ngn_tagged(tag)
 local res={}
 for e in all(st.ent) do
  if(e.tag and e.tag==tag)then
   add(res,e)
  elseif(e.tags)then
   local added=false
   for t in all(e.tags) do 
    if(not added and (t == tag)) added=true add(res,e)
   end
  end
 end
 return res
end

-- remove e from st.ent[]
-- but also mark as __destr so
-- game loop will skip it
function ngn_rem(e)
 e.__rem=true
 del(st.ent,e)
end

function ngn_upd()
 if(st.freeze and st.freeze>0)then
  st.freeze -= timed(1)
  if(st.freeze <= 0)then
    del(st, st.freeze)
  end
  return--no update this time!
 end
 
 if(st.shake) st.shake.upd()
 if(st.upd) st.upd(st)
 -- ent updates
 local cloned={}
 for e in all(st.ent) do
  add(cloned, e)
 end
 for e in all(cloned) do
  if(e.upd and not e.__rem and not __ngn_scene_switched) e.upd(e,st)
 end
 for e in all(cloned) do
  if(e.late_upd and not e.__rem and not __ngn_scene_switched) e.late_upd(e,st)
 end
 if(st.late_upd and not __ngn_scene_switched) st.late_upd(st)
 __ngn_scene_switched = false
end

function ngn_drw()
 if(st.shake)then camera(st.shake.x,st.shake.y) else camera() end
 if(st.drw) st.drw(st)
 for i=0,6 do
  foreach(st.ent,function(e) if(e.layer == i and e.drw)then e.drw(e,st) end end)
 end
 if(debug)then

 end
end

__gfx__
00000000000000a00a000000000000a00a0000000aaaaaa00aaaaaa0000000000000000011111111200200022020020002020022202200020002000000002000
000000000000009009000000000000900900000009c99c9009c99c90000000000000000011111111200200022020020020200200232b30020002200000022000
00700700000000d99d000000000000d99d000000097997900979979000a0000000000a001dd611112032b30220320200232020002bbbb2200002200000022000
0007700000000005500000000000000550000000014444100144441000a00000000009005555511102bbbb20023bb3200bbb30000b7bb0000003200000023000
00077000000aaaaaaaa60000000aaaaaaaa60000a499994aa499994a00900000000009001dd6111100b7bb0000bbbb0007bbb00000bb0000002bb000000bb200
007007000009c999c99900000009c999c999000005dd5dd00dd5dd50009100000000190055555111000bb00000b7b00003bb000000000000002bb300003bbb00
0000000000097999799949000949799979990000561221655612216d00199991199991005dd6111100000000000bb0000000000000000000003bbb00003bb700
00000000094999999999000000099999999949000dd5dd5005dd55d0000000155100000055551111000000000000000000000000000000000007b7000007b300
11111111000144444441000000014444444100000999999009c99c90000000000000600000000000500100015555555500000000000000000000000000000000
11111111000029999920000000002999992000000999999009799790000000000000d00000000000500100015555555500000000000000000000000000000000
11111111005dd5dd5dd5d00000dd5dd5dd5dd0000aaaaaa0a999999a000000000000600000000000501111115555555500000000000000000000000000000000
111111100d11111111111d0005111111111115000499994001444410000000000000d00000000000510000015555555502020002200020200000000000000000
11111110d1d6d55555d6d150d1d6d55555d6d1d00949949000999900000000000000600000000006566666665555555502020002200200200000000000000000
11111110516665d5d56661d0d16665d5d56661d0a5dd5dda05dd5dd0000000000000d0000000006555555555155555550207b7200207b7200000000000000000
11111110d1d6d51515d6d1d051d6d51515d6d150561221655612216500a00a0000006000000000651111111515555555003bbb30003bbb300000000000000000
11111110001000000000100000100000000010000dd5dd500dd5dd50009559000000d000000000651111111515555555003bbb300003bb300000000000000000
11111110555555550000000055555555555555555565555500000000000000000000000011000065111111151555555500000001000000000000000000000000
1111111055555555000000001111111155d111111111111100019990000000000000000011000065111111151555555500000001000000000000000000000000
1111111055555555000000005555555555555555555d555509999990000000000000000010001165111111151555555500000001000000000000000000000000
11111110555555550000000055555555555555555555d55509999aa0000011100000000010010065111111151555555500000001000000000000000000000000
11111110555555550000000055555555555555555555d55549aaa994099999900000000010010065111111151555555500000001000000000000000000000000
1111111055555555000000005555555555555555555555550a999990199999910000000010010065111111151555555500000111000000000000000000000000
111111105555555500000000555555555555555555555555594494d5599999950000000010010065111111151555555500001001000000000000000000000000
1111111055555555000000005555555555555555555555550dd5dd505999aaa50000000010010065111111151555555500001001000000000000000000000000
11111110000000001111111000000000011111110000000011111111001111110000000011110065111111155551555500000001100000000000000000000000
1111111100000000111111100000000001111111000000001111111100111111000000001001006511111115111d555500000001100000000000000000000000
11111111000000001111111000000000001111110000000011111111001111110000000015050565111111155555555500000001100000000000000000000000
111111110000000011111111000000000011111100000000111111110111111100000000556565d5111111155555555500000001100000000000000000000000
11111111110000001011010000011000001111110000000011111111101111110000000055d5d5d5111111155555555500000001100000000000000000000000
11111110101000001011110011011110001111110000000011111111101111110000000055d5d5d5111111155555555500000001100000000000000000000000
11111110101000001011010011111001001111110000000011111111101111110000000055d5d5d5111111155555555500000001100000000000000000000000
11111111111111111011110011011001001111110011111011111111101111110000000055d5d5d5111111155555555500000001100000000000000000000000
00000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000077100000007d0077710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077710070007770077710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777710777077717777777100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00177710177777100777771000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00017710017771000077710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001710001710000007100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000110000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000001555555550000000155555555005100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000001555555550000000001115555005100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000001555555550000000000111115555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000006ddd5d55550000000000111d55151111151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000d5555555550000000000111555015000510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000d555555555000000000011115500150d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011155555550000000011111155555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000015555555500000000011dd555111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555550000000001155555100055001051000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555550000000011155555105511001051000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555dd5550000000001d5555555110000d555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
55dd555555d55d550000006ddd555555110000001511111500000000000000000000000000000000000000000000000000000000000000000000000000000000
5551555555d55555000000d555555555100000001150005100000000000000000000000000000000000000000000000000000000000000000000000000000000
55555d5555555555000000d5555555551000000010150d1000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555d555550000001155555555100000005555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555550000000155555555100000001111115500000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555100000005555555555555555555555510010010000000000000000000000000000000000000000000000000000000000000000000000000000000000
555555551000000055555d5555555555555555110010000000000000000000000000000000000000000000000000000000000000000000000000000000000000
555555551000000055555555555dd555555555110010000000000000000000000000000000000000000000000000000000000000000000000000000000000000
555555dddd0000005555555555d55d55555d5dd60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
555555555d0000005555555555555d55555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
555555555d0000005555d55555555555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555551110000005555555555555555555555150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555100000005555555555555555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
21655454545454545454550000003c6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21640000750000007500000000003c2100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
733d000000000000000000000000525300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071000000000000000000000000626300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
213d0000000000000000000000003c2100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
603d0000000000000000000000003c6100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071000000000000000000000000505100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
213d0000000000000000000000003c2100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
733d0000000000000000000000003c6100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7410000000000000000000000000505100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21200000000000000000000000002c2100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
72100000000000000000000035191a1b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21303100000000000000003436292a2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21093200003300000000003736393a2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21242323252323232323232323233b2100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

