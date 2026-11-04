' Layout is authored at 1920x1080 and the panel Group is scaled to the UI resolution.
sub init()
    PANEL_W = 1100
    PANEL_H = 660
    m.rowH = 120
    m.rowsY = 200
    dr = m.top.currentDesignResolution
    s = dr.width / 1920.0

    backdrop = m.top.findNode("backdrop")
    backdrop.width = 2546 * s
    backdrop.height = 1080 * s
    backdrop.translation = [-313 * s, 0]
    shade = m.top.findNode("dim")
    shade.width = dr.width
    shade.height = dr.height

    panel = m.top.findNode("panel")
    panel.scale = [s, s]
    panel.translation = [(dr.width - PANEL_W * s) / 2, (dr.height - PANEL_H * s) / 2]
    m.top.findNode("panelBg").width = PANEL_W
    m.top.findNode("panelBg").height = PANEL_H
    edge = m.top.findNode("panelEdge")
    edge.width = PANEL_W
    edge.height = 4
    edge.translation = [0, 0]

    titleFont = "font:LargeBoldSystemFont"
    bodyFont = "font:MediumBoldSystemFont"
    smallFont = "font:SmallestSystemFont"
    settingsUiPlace(m.top.findNode("title"), titleFont, 60, 36, PANEL_W - 120, 90)
    settingsUiPlace(m.top.findNode("subtitle"), smallFont, 60, 122, PANEL_W - 120, 40)
    settingsUiPlace(m.top.findNode("hint"), smallFont, 60, PANEL_H - 70, PANEL_W - 120, 40)

    highlight = m.top.findNode("highlight")
    highlight.width = PANEL_W - 60
    highlight.height = m.rowH - 16
    m.highlight = highlight

    m.keys = settingsKeys()
    m.titles = { nightMode: "Night mode", density: "Fish density", drift: "Camera drift" }
    m.shown = {
        nightMode: { auto: "Auto", day: "Always day", night: "Always night" }
        density: { calm: "Calm", normal: "Normal", busy: "Busy" }
        drift: { on: "On", off: "Off" }
    }
    m.store = settingsRegistryStore()
    m.values = settingsLoad(m.store)
    m.row = 0

    rows = m.top.findNode("rows")
    m.nameLabels = []
    m.valueLabels = []
    for i = 0 to m.keys.count() - 1
        y = m.rowsY + i * m.rowH
        name = rows.createChild("Label")
        settingsUiPlace(name, bodyFont, 90, y + 18, 440, 70)
        name.text = m.titles[m.keys[i]]
        value = rows.createChild("Label")
        settingsUiPlace(value, bodyFont, 540, y + 18, PANEL_W - 540 - 90, 70)
        value.horizAlign = "right"
        m.nameLabels.push(name)
        m.valueLabels.push(value)
    end for
    settingsUiRefresh()
    m.top.setFocus(true)
end sub

sub settingsUiPlace(label as object, font as string, x as integer, y as integer, w as integer, h as integer)
    label.font = font
    label.translation = [x, y]
    label.width = w
    label.height = h
    label.vertAlign = "center"
end sub

' Redraws the values (with arrows on the focused row) and moves the highlight.
sub settingsUiRefresh()
    for i = 0 to m.keys.count() - 1
        key = m.keys[i]
        text = m.shown[key][m.values[key]]
        if i = m.row
            text = "<   " + text + "   >"
            m.nameLabels[i].color = "0xFFFFFFFF"
            m.valueLabels[i].color = "0xFFE9A8FF"
        else
            m.nameLabels[i].color = "0xBFDDEBFF"
            m.valueLabels[i].color = "0x9FD0E6FF"
        end if
        m.valueLabels[i].text = text
    end for
    m.highlight.translation = [30, m.rowsY + m.row * m.rowH + 8]
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    count = m.keys.count()
    if key = "up"
        m.row = (m.row + count - 1) mod count
    else if key = "down" or key = "OK"
        m.row = (m.row + 1) mod count
    else if key = "left" or key = "right"
        dir = 1
        if key = "left" then dir = -1
        k = m.keys[m.row]
        m.values[k] = settingsStep(k, m.values[k], dir)
        settingsSave(m.store, m.values)
    else
        ' Back (and anything else) is left to the platform, which closes the screen.
        return false
    end if
    settingsUiRefresh()
    return true
end function
