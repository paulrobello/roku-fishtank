' Unit tests for components/lib/bubbles.brs (P1.3 pooled bubble column).

function bubblesTestSuite() as object
    return {
        name: "bubbles"
        tests: [
            { name: "poolSizeConstantOver10000Recycles", fn: bubblesTest_poolSizeConstantOver10000Recycles }
            { name: "recycledCyclesStayInRange", fn: bubblesTest_recycledCyclesStayInRange }
            { name: "sameSeedSameSchedule", fn: bubblesTest_sameSeedSameSchedule }
            { name: "slotStreamsIndependentOfOrder", fn: bubblesTest_slotStreamsIndependentOfOrder }
            { name: "columnIsContinuous", fn: bubblesTest_columnIsContinuous }
            { name: "keyframesMatchPose", fn: bubblesTest_keyframesMatchPose }
        ]
    }
end function

function bubblesTestCfg() as object
    return {
        pool: 40
        sources: [{ x: 1150, y: 1000, top: -40, spread: 8 }, { x: 1540, y: 960, top: -40, spread: 6 }]
        sizeMin: 8
        sizeMax: 24
        riseMin: 6.0
        riseMax: 9.0
        gapMax: 0.5
    }
end function

sub bubblesTest_poolSizeConstantOver10000Recycles(t as object)
    pool = bubblesNewPool(bubblesTestCfg(), 7)
    first = []
    for each s in pool.slots
        first.push(s)
    end for
    rng = prngNew(99)
    now = 0.0
    for r = 1 to 10000
        i = prngNextU32(rng) mod pool.slots.count()
        now = now + 0.05
        bubblesRecycle(pool, i, now)
        if pool.slots.count() <> 40 then
            assertEqual(t, pool.slots.count(), 40, "pool size after recycle " + r.toStr())
            return
        end if
    end for
    assertEqual(t, pool.recycles, 10000, "recycle count")
    ' Same slot objects in the same order: recycling rewrites cycles, never slots.
    for i = 0 to 39
        if not assertTrue(t, pool.slots[i].index = i and pool.slots[i].source.x = first[i].source.x, "slot " + i.toStr() + " kept its index and source") then return
    end for
    ' The scheduler's own path (advance to a far time) keeps the pool fixed too.
    pool2 = bubblesNewPool(bubblesTestCfg(), 3)
    bubblesAdvanceTo(pool2, 1800.0)
    assertEqual(t, pool2.slots.count(), 40, "pool size after 30 min of scheduled recycles")
    assertTrue(t, pool2.recycles > 7000, "scheduled recycles over 30 min: " + pool2.recycles.toStr())
end sub

sub bubblesTest_recycledCyclesStayInRange(t as object)
    pool = bubblesNewPool(bubblesTestCfg(), 11)
    for r = 0 to 1999
        c = bubblesRecycle(pool, r mod 40, r * 0.1).cycle
        ok = c.size >= 8 and c.size <= 24.01 and c.rise >= 6 and c.rise < 9 and c.delay >= 0 and c.delay < 0.5 and c.p0 = 0 and c.amp >= 3 and c.amp <= 10.01
        if not assertTrue(t, ok, "cycle " + r.toStr() + " in range") then return
    end for
end sub

sub bubblesTest_sameSeedSameSchedule(t as object)
    a = bubblesNewPool(bubblesTestCfg(), 42)
    b = bubblesNewPool(bubblesTestCfg(), 42)
    bubblesAdvanceTo(a, 120.0)
    bubblesAdvanceTo(b, 120.0)
    for i = 0 to 39
        pa = bubblesPoseAt(a, a.slots[i].cycle, 120.0)
        pb = bubblesPoseAt(b, b.slots[i].cycle, 120.0)
        if not assertTrue(t, pa.translation[0] = pb.translation[0] and pa.translation[1] = pb.translation[1], "slot " + i.toStr() + " pose") then return
    end for
end sub

' A live run recycles slots in completion order; a frozen pose advances slot by slot.
' Both must give each slot the same cycles.
sub bubblesTest_slotStreamsIndependentOfOrder(t as object)
    a = bubblesNewPool(bubblesTestCfg(), 5)
    b = bubblesNewPool(bubblesTestCfg(), 5)
    for r = 1 to 5
        for i = 0 to 39
            bubblesRecycle(a, i, 0.0)
        end for
        for i = 39 to 0 step -1
            bubblesRecycle(b, i, 0.0)
        end for
    end for
    for i = 0 to 39
        if not assertEqual(t, a.slots[i].cycle.size, b.slots[i].cycle.size, "slot " + i.toStr() + " size") then return
    end for
end sub

' Sampled every second over 10 minutes, each source always has several visible bubbles
' and no vertical gap between them (or to the source and top) exceeds 400 px (under 40% of the rise).
sub bubblesTest_columnIsContinuous(t as object)
    cfg = bubblesTestCfg()
    pool = bubblesNewPool(cfg, 9)
    for n = 0 to 600
        now = n * 1.0
        bubblesAdvanceTo(pool, now)
        for s = 0 to cfg.sources.count() - 1
            src = cfg.sources[s]
            ys = []
            for i = s to 39 step cfg.sources.count()
                p = bubblesPoseAt(pool, pool.slots[i].cycle, now)
                if p.u >= 0 then ys.push(p.translation[1])
            end for
            if not assertTrue(t, ys.count() >= 8, "source " + s.toStr() + " at t=" + now.toStr() + " has " + ys.count().toStr() + " bubbles") then return
            ys.sort()
            gap = ys[0] - src.top
            for k = 1 to ys.count() - 1
                if ys[k] - ys[k - 1] > gap then gap = ys[k] - ys[k - 1]
            end for
            if src.y - ys[ys.count() - 1] > gap then gap = src.y - ys[ys.count() - 1]
            if not assertTrue(t, gap < 400, "source " + s.toStr() + " at t=" + now.toStr() + " largest gap " + gap.toStr()) then return
        end for
    end for
end sub

sub bubblesTest_keyframesMatchPose(t as object)
    pool = bubblesNewPool(bubblesTestCfg(), 13)
    c = pool.slots[3].cycle
    kf = bubblesKeyframes(pool, c)
    assertEqual(t, kf.keys.count(), 13, "key count")
    last = kf.keys.count() - 1
    pStart = bubblesPoseAt(pool, c, c.start + c.delay)
    pEnd = bubblesPoseAt(pool, c, bubblesCycleEnd(c))
    assertNear(t, kf.translations[0][1], pStart.translation[1], 0.01, "first key y")
    assertNear(t, kf.translations[last][1], pEnd.translation[1], 0.01, "last key y")
    assertNear(t, kf.opacities[last], 0.0, 0.001, "faded out at the top")
end sub
