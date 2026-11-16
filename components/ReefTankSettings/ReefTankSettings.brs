' Layout is authored at 1920x1080 and the panel Group is scaled to the UI resolution.
sub init()
    PANEL_W = 1100
    PANEL_H = 760
    m.rowH = 110
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
    m.keys.push("solarLocation")
    m.titles = { nightMode: "Night mode", density: "Fish density", drift: "Camera drift" }
    m.shown = {
        nightMode: { auto: "Auto", day: "Always day", night: "Always night" }
        density: { calm: "Calm", normal: "Normal", busy: "Busy" }
        drift: { on: "On", off: "Off" }
    }
    m.store = settingsRegistryStore()
    m.values = settingsLoad(m.store)
    m.location = settingsLocationLoad(m.store)

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
        if key = "solarLocation" then
            m.options.content.getChild(i).title = "Solar location: " + settingsLocationLabel(m.location)
        else
            m.options.content.getChild(i).title = m.titles[key] + ": " + m.shown[key][m.values[key]]
        end if
    end for
end sub

sub settingsUiSelected()
    row = m.options.itemSelected
    if row < 0 or row >= m.keys.count() then return
    key = m.keys[row]
    if key = "solarLocation" then
        settingsUiLocation()
        return
    end if
    m.values[key] = settingsStep(key, m.values[key], 1)
    settingsSave(m.store, m.values)
    settingsUiRefresh()
end sub

sub settingsUiLocation()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Solar location"
    dialog.message = "Choose a city or enter coordinates. Keep your Roku time zone correct. Location stays on this device."
    dialog.buttons = ["Woodland, CA", "Charlotte, NC", "Custom coordinates", "Cancel"]
    dialog.observeField("buttonSelected", "settingsUiLocationSelected")
    dialog.observeField("wasClosed", "settingsUiDialogClosed")
    m.top.dialog = dialog
end sub

sub settingsUiLocationSelected(event as object)
    choice = event.getData()
    dialog = m.top.dialog
    if choice = 2 then
        dialog.close = true
        keyboard = CreateObject("roSGNode", "KeyboardDialog")
        keyboard.title = "Latitude, longitude"
        keyboard.message = "Example: 35.2271,-80.8431. North/east positive, south/west negative."
        keyboard.text = m.location.text
        keyboard.buttons = ["Save", "Cancel"]
        keyboard.observeField("buttonSelected", "settingsUiCoordinatesSelected")
        keyboard.observeField("wasClosed", "settingsUiDialogClosed")
        m.top.dialog = keyboard
        return
    end if
    if choice = 0 then settingsLocationSave(m.store, "38.68,-121.77")
    if choice = 1 then settingsLocationSave(m.store, "35.2271,-80.8431")
    m.location = settingsLocationLoad(m.store)
    settingsUiRefresh()
    dialog.close = true
end sub

sub settingsUiCoordinatesSelected(event as object)
    dialog = m.top.dialog
    if event.getData() = 0 then
        if not settingsLocationSave(m.store, dialog.text) then
            dialog.title = "Invalid coordinates"
            dialog.message = "Enter latitude (-90 to 90), longitude (-180 to 180), separated by a comma."
            return
        end if
        m.location = settingsLocationLoad(m.store)
        settingsUiRefresh()
    end if
    dialog.close = true
end sub

sub settingsUiDialogClosed()
    if m.top.dialog = invalid then
        m.options.setFocus(true)
    else if m.top.dialog.wasClosed then
        m.options.setFocus(true)
    end if
end sub
