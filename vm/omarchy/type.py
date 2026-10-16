#!/usr/bin/env python3
# type.py "text" [key ...]  -> sendkey per char, then extra named keys (e.g. ret, tab, down)
import subprocess,sys,os
m={' ':'spc','-':'minus','=':'equal','.':'dot',',':'comma','/':'slash',';':'semicolon',"'":'apostrophe','\\':'backslash','[':'bracket_left',']':'bracket_right','`':'grave_accent'}
sh={'!':'1','@':'2','#':'3','$':'4','%':'5','^':'6','&':'7','*':'8','(':'9',')':'0','_':'minus','+':'equal',':':'semicolon','"':'apostrophe','<':'comma','>':'dot','?':'slash','|':'backslash','~':'grave_accent','{':'bracket_left','}':'bracket_right'}
cmds=[]
for ch in sys.argv[1]:
    if ch.isupper(): cmds.append('sendkey shift-'+ch.lower())
    elif ch in sh: cmds.append('sendkey shift-'+(m.get(sh[ch],sh[ch])))
    elif ch in m: cmds.append('sendkey '+m[ch]+' 10')
    else: cmds.append('sendkey '+ch+' 10')
cmds += ['sendkey '+k for k in sys.argv[2:]]
cmds=[c if c.endswith(' 10') else c+' 10' for c in cmds]
subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__),'mon.py')]+cmds)
