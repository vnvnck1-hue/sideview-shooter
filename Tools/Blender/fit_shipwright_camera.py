"""Measure a best orthographic camera against visible concept landmarks.

This reports projection residuals rather than pretending a camera fit proves identity.
Run with a saved shipwright.blend as InputBlend. It does not change the asset.
"""
import math
import json
import sys
from pathlib import Path

points=[
    ('monitor',(0,1.34,4.55),(696,192)),
    ('central_eye',(0,-2.44,2.35),(459,558)),
    ('right_eye',(1.22,-1.47,2.60),(638,535)),
    ('left_eye',(-1.22,-1.47,2.60),(399,500)),
    ('right_cheek',(1.05,-2.18,1.98),(534,617)),
    ('left_cheek',(-1.05,-2.18,1.98),(368,579)),
    ('right_front_foot',(2.61,-1.10,.18),(837,924)),
    ('left_front_foot',(-2.61,-1.10,.18),(147,733)),
    ('right_rear_foot',(2.61,1.83,.18),(935,744)),
    ('left_rear_knee',(-1.72,1.22,2.77),(402,389)),
    ('saw',(2.015,-2.15,.47),(596,877)),
    ('rotary_tip',(0,-2.86,1.10),(389,747)),
    ('right_hand',(1.02,-2.58,.81),(509,801)),
    ('left_hand',(-1.02,-2.58,.81),(282,741)),
    ('antenna',(-.49,-.38,4.16),(468,351)),
]
n=len(points);meanx=sum(p[2][0] for p in points)/n;meany=sum(p[2][1] for p in points)/n
best=None
for yaw_i in range(30,141):
    yaw=math.radians(yaw_i*.5)
    for elev_i in range(20,121):
        elev=math.radians(elev_i*.5)
        right=(math.cos(yaw),math.sin(yaw),0)
        up=(-math.sin(yaw)*math.sin(elev),math.cos(yaw)*math.sin(elev),math.cos(elev))
        q=[(sum(p[1][k]*right[k] for k in range(3)),-sum(p[1][k]*up[k] for k in range(3))) for p in points]
        mx=sum(t[0] for t in q)/n;my=sum(t[1] for t in q)/n
        denom=sum((t[0]-mx)**2+(t[1]-my)**2 for t in q)
        scale=sum((t[0]-mx)*(p[2][0]-meanx)+(t[1]-my)*(p[2][1]-meany) for t,p in zip(q,points))/denom
        tx=meanx-scale*mx;ty=meany-scale*my
        err=sum((scale*t[0]+tx-p[2][0])**2+(scale*t[1]+ty-p[2][1])**2 for t,p in zip(q,points))
        if best is None or err<best[0]:best=(err,yaw_i*.5,elev_i*.5,scale,tx,ty,q)
err,yaw,elev,scale,tx,ty,q=best
report={'yaw_degrees':yaw,'elevation_degrees':elev,'pixels_per_unit':scale,'offset_x':tx,'offset_y':ty,'landmark_rmse_pixels':math.sqrt(err/n),'landmarks':[]}
report['measurement_note']='Manually estimated visible landmarks, with occluded feature centers approximated. Informational comparison only, not proof of exact reconstruction.'
for t,p in zip(q,points):
    pred=(round(scale*t[0]+tx,1),round(scale*t[1]+ty,1))
    report['landmarks'].append({'name':p[0],'reference_px':p[2],'predicted_px':pred,'error_px':round(math.dist(pred,p[2]),1)})
out=Path(__file__).resolve().parents[2]/'Deliverables'/'Shipwright'
(out/'projection_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PROJECTION_AUDIT',json.dumps(report))
if '--perspective' in sys.argv:
    bestp=None
    for yaw_i in range(18,51):
        yaw=math.radians(yaw_i)
        for elev_i in range(12,46):
            elev=math.radians(elev_i)
            right=(math.cos(yaw),math.sin(yaw),0)
            up=(-math.sin(yaw)*math.sin(elev),math.cos(yaw)*math.sin(elev),math.cos(elev))
            direction=(math.sin(yaw)*math.cos(elev),-math.cos(yaw)*math.cos(elev),math.sin(elev))
            flat=[]
            for p in points:
                vec=(p[1][0],p[1][1],p[1][2]-2.5)
                flat.append((sum(vec[k]*right[k] for k in range(3)),-sum(vec[k]*up[k] for k in range(3)),sum(vec[k]*direction[k] for k in range(3))))
            for di in range(16,61):
                distance=di*.5
                q=[(t[0]/(distance-t[2]),t[1]/(distance-t[2])) for t in flat]
                mx=sum(t[0] for t in q)/n;my=sum(t[1] for t in q)/n
                denom=sum((t[0]-mx)**2+(t[1]-my)**2 for t in q)
                scale=sum((t[0]-mx)*(p[2][0]-meanx)+(t[1]-my)*(p[2][1]-meany) for t,p in zip(q,points))/denom
                tx=meanx-scale*mx;ty=meany-scale*my
                err=sum((scale*t[0]+tx-p[2][0])**2+(scale*t[1]+ty-p[2][1])**2 for t,p in zip(q,points))
                if bestp is None or err<bestp[0]:bestp=(err,yaw_i,elev_i,distance,scale,tx,ty)
    err,yaw,elev,distance,scale,tx,ty=bestp
    perspective={'yaw_degrees':yaw,'elevation_degrees':elev,'distance':distance,'focal_pixels':scale,'offset_x':tx,'offset_y':ty,'target':[0,0,2.5],'landmark_rmse_pixels':math.sqrt(err/n),'measurement_note':report['measurement_note']}
    (out/'perspective_projection_audit.json').write_text(json.dumps(perspective,indent=2),encoding='utf-8')
    print('PERSPECTIVE_AUDIT',json.dumps(perspective))
