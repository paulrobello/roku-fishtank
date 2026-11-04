sub init()
    m.uri = "pkg:/images/fish/royal_blue_tang_body.png"
    m.w = 390
    m.h = 226
    cells = [
        "A reference",
        "B Poster scale -1",
        "C Poster scale -1, rotation 0.001",
        "D Poster scale -1, rotation 2pi",
        "E Group scale -1, Poster plain",
        "F Group scale -1, Poster rotation 0.001",
        "G Group scale -1 animated",
        "H Poster scale -0.999"
    ]
    for i = 0 to cells.count() - 1
        x = (i mod 4) * 480 + 45
        y = int(i / 4) * 540 + 150
        label = createObject("roSGNode", "Label")
        label.text = cells[i]
        label.translation = [x, y - 90]
        m.top.appendChild(label)
        holder = createObject("roSGNode", "Group")
        holder.translation = [x, y]
        m.top.appendChild(holder)
        addCell(i, holder)
    end for
    print "MIRRORPROBE ready"
end sub

function makePoster() as object
    p = createObject("roSGNode", "Poster")
    p.uri = m.uri
    p.width = m.w
    p.height = m.h
    p.scaleRotateCenter = [m.w / 2, m.h / 2]
    return p
end function

sub addCell(i as integer, holder as object)
    p = makePoster()
    if i = 1 then
        p.scale = [-1.0, 1.0]
    else if i = 2 then
        p.scale = [-1.0, 1.0]
        p.rotation = 0.001
    else if i = 3 then
        p.scale = [-1.0, 1.0]
        p.rotation = 6.283185
    else if i = 7 then
        p.scale = [-0.999, 1.0]
    end if
    if i < 4 or i = 7 then
        holder.appendChild(p)
        return
    end if
    g = createObject("roSGNode", "Group")
    g.id = "mirrorGroup" + i.toStr()
    g.scaleRotateCenter = [m.w / 2, m.h / 2]
    if i = 5 then p.rotation = 0.001
    g.appendChild(p)
    holder.appendChild(g)
    if i = 6 then
        anim = createObject("roSGNode", "Animation")
        anim.duration = 1.0
        anim.repeat = false
        interp = createObject("roSGNode", "Vector2DFieldInterpolator")
        interp.fieldToInterp = [g.id + ".scale"]
        interp.key = [0.0, 1.0]
        interp.keyValue = [[1.0, 1.0], [-1.0, 1.0]]
        anim.appendChild(interp)
        holder.appendChild(anim)
        anim.control = "start"
    else
        g.scale = [-1.0, 1.0]
    end if
end sub
