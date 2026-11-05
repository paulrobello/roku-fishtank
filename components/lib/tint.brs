' Lane scale and tint for rigged fish (P2.7). SceneGraph Groups have no blendColor,
' so the tint is multiplied into every Poster under the Fish. Call it after species
' is set: Fish creates its extra layer Posters when the species loads. Nodes whose id
' starts with "night" (a light organ's glow) keep their own colour, as under Night.
sub laneTintPosters(node as object, color as integer)
    if Left(node.id, 5) = "night" then return
    if node.subtype() = "Poster" then node.blendColor = color
    for i = 0 to node.getChildCount() - 1
        laneTintPosters(node.getChild(i), color)
    end for
end sub

' Scale pivots on anchor (the rig mirror_center the brain steers), so the drawn fish
' stays on its steered point; scale stays positive (docs/fidelity F4). Scale 1 and
' opaque white (-1) leave the Fish untouched.
sub laneStyleFish(node as object, anchor as object, scale as float, tint as integer)
    if scale <> 1.0 then
        node.scaleRotateCenter = [anchor[0], anchor[1]]
        node.scale = [scale, scale]
    end if
    if tint <> -1 then laneTintPosters(node, tint)
end sub

' Sets both the lane scale and tint whatever their values (a fish changing lane, P2.4).
sub laneSetStyle(node as object, anchor as object, scale as float, tint as integer)
    node.scaleRotateCenter = [anchor[0], anchor[1]]
    node.scale = [scale, scale]
    laneTintPosters(node, tint)
end sub
