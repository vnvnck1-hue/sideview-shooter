import numpy as np


def search(src1, src2, t1, t2, src_area, root, feed, optic, root_goal, feed_goal, optic_goal):
    tp = np.array((320, 320))
    arr = []
    for x in range(100, 801, 10):
        for y in range(600, 1101, 10):
            sp = np.array((x, y))
            basis = np.column_stack((src1 - sp, src2 - sp))
            if abs(np.linalg.det(basis)) < 1000:
                continue
            forward = np.column_stack((t1 - tp, t2 - tp)) @ np.linalg.inv(basis)
            area = src_area * abs(np.linalg.det(forward))
            new_root = tp + forward @ (root - sp)
            new_feed = tp + forward @ (feed - sp)
            new_optic = tp + forward @ (optic - sp)
            score = (np.sum((new_root-root_goal)**2) + np.sum((new_feed-feed_goal)**2)
                     + .5*np.sum((new_optic-optic_goal)**2) + .02*(area-30642)**2)
            arr.append((score, x, y, round(area), new_root.round().astype(int),
                        new_feed.round().astype(int), new_optic.round().astype(int)))
    for result in sorted(arr, key=lambda item: item[0])[:10]:
        print(result)


search(np.array((1070,326)), np.array((1115,470)), np.array((348,80)),
       np.array((375,100)), 424004, np.array((760,650)), np.array((160,900)),
       np.array((600,480)), np.array((294,199)), np.array((257,335)),
       np.array((218,202)))
