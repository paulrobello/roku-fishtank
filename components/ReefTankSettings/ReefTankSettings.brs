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

    m.keys = settingsKeys()
    m.titles = { nightMode: "Night mode", density: "Fish density", drift: "Camera drift" }
    m.shown = {
        nightMode: { auto: "Auto", day: "Always day", night: "Always night" }
        density: { calm: "Calm", normal: "Normal", busy: "Busy" }
        drift: { on: "On", off: "Off" }
    }
    m.store = settingsRegistryStore()
    m.values = settingsLoad(m.store)

    ' Native list navigation handles Up/Down and OK in the separate settings context.
    ' No custom key handler is included in the screensaver package.
    m.options = m.top.findNode("options")
    m.options.translation = [60, m.rowsY]
    m.options.itemSize = [PANEL_W - 120, m.rowH]
    m.options.itemSpacing = [0, 0]
    m.options.numRows = m.keys.count()
    m.options.font = bodyFont
    m.options.focusedFont = bodyFont
    content = createObject("roSGNode", "ContentNode")
    for each key in m.keys
        content.createChild("ContentNode")
    end for
    m.options.content = content
    settingsUiRefresh()
    m.options.observeField("itemSelected", "settingsUiSelected")
    m.options.setFocus(true)
end sub

sub settingsUiPlace(label as object, font as string, x as integer, y as integer, w as integer, h as integer)
    label.font = font
    label.translation = [x, y]
    label.width = w
    label.height = h
    label.vertAlign = "center"
end sub

' Update native list labels without replacing its content or moving focus.
sub settingsUiRefresh()
    for i = 0 to m.keys.count() - 1
        key = m.keys[i]
        m.options.content.getChild(i).title = m.titles[key] + ": " + m.shown[key][m.values[key]]
    end for
end sub

sub settingsUiSelected()
    row = m.options.itemSelected
    if row < 0 or row >= m.keys.count() then return
    key = m.keys[row]
    m.values[key] = settingsStep(key, m.values[key], 1)
    settingsSave(m.store, m.values)
    settingsUiRefresh()
end sub
