local root=assert(app.params.root)
local dir=app.fs.joinPath(root,'research-images','creatures-v2')
local s=Sprite(800,450,ColorMode.RGB)
s.layers[1].name='Actual Godot gameplay capture'
for i=0,58,2 do
 if i>0 then s:newEmptyFrame() end
 local im=Image{fromFile=app.fs.joinPath(dir,string.format('frame_%03d.png',i))}
 im:resize(800,450)
 s:newCel(s.layers[1],#s.frames,im,Point(0,0))
 s.frames[#s.frames].duration=2/30
end
s:saveAs(app.fs.joinPath(dir,'game-motion.gif'))
s:close()
print('GAME_MOTION_GIF_OK')
