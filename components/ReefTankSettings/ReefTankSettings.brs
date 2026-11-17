' Layout is authored at 1920x1080 and the panel Group is scaled to the UI resolution.
sub init()
    PANEL_W = 1100
    PANEL_H = 760
    m.rowH = 80
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

    ' Keep Solar location at index 3 even when new persisted preferences are added.
    m.keys = ["nightMode", "density", "drift", "solarLocation", "digitalClock", "changelog"]
    m.titles = { nightMode: "Night mode", density: "Fish density", drift: "Camera drift", digitalClock: "Background clock" }
    m.shown = {
        nightMode: { auto: "Auto", day: "Always day", night: "Always night" }
        density: { calm: "Calm", normal: "Normal", busy: "Busy" }
        drift: { on: "On", off: "Off" }
        digitalClock: { on: "On", off: "Off" }
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
    m.places = m.top.findNode("places")
    m.places.observeField("itemSelected", "settingsUiPlaceSelected")
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
        else if key = "changelog" then
            m.options.content.getChild(i).title = "Changelog"
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
    if key = "changelog" then
        m.changelogEntries = ParseJson(ReadAsciiFile("pkg:/config/changelog.json"))
        if m.changelogEntries = invalid then return
        if m.changelogEntries.count() = 0 then return
        m.changelogIndex = 0
        settingsUiChangelog()
        return
    end if
    m.values[key] = settingsStep(key, m.values[key], 1)
    settingsSave(m.store, m.values)
    settingsUiRefresh()
end sub

sub settingsUiLocation()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Solar location"
    dialog.message = "Choose a ZIP, nearby city, or coordinates. Keep your Roku time zone correct. Location stays on this device."
    dialog.buttons = ["US ZIP code", "Country / city", "Custom coordinates", "Cancel"]
    dialog.observeField("buttonSelected", "settingsUiLocationSelected")
    dialog.observeField("wasClosed", "settingsUiDialogClosed")
    m.top.dialog = dialog
end sub

sub settingsUiLocationSelected(event as object)
    choice = event.getData()
    dialog = m.top.dialog
    dialog.close = true
    if choice = 0 then
        keyboard = CreateObject("roSGNode", "StandardKeyboardDialog")
        keyboard.title = "US ZIP code"
        keyboard.message = ["Enter five digits, then select Save ZIP below the keyboard."]
        keyboard.keyboardDomain = "numeric"
        keyboard.buttons = ["Save ZIP", "Use remote digits", "Cancel"]
        keyboard.observeField("buttonSelected", "settingsUiZipKeyboardSelected")
        keyboard.observeField("wasClosed", "settingsUiDialogClosed")
        m.top.dialog = keyboard
    else if choice = 1 then
        settingsUiCountries()
    else if choice = 2 then
        keyboard = CreateObject("roSGNode", "StandardKeyboardDialog")
        keyboard.title = "Latitude, longitude"
        keyboard.message = ["Example: 35.2271,-80.8431. Select Save below the keyboard."]
        keyboard.text = m.location.text
        keyboard.buttons = ["Save", "Cancel"]
        keyboard.observeField("buttonSelected", "settingsUiCoordinatesSelected")
        keyboard.observeField("wasClosed", "settingsUiDialogClosed")
        m.top.dialog = keyboard
    end if
end sub

sub settingsUiZipKeyboardSelected(event as object)
    dialog = m.top.dialog
    choice = event.getData()
    if choice = 0 then
        loc = locationZipRead(dialog.text.trim())
        if loc = invalid then
            dialog.title = "ZIP not found"
            dialog.message = ["Use five digits including leading zeros. Some ZIPs need city / coordinates instead."]
            return
        end if
        settingsLocationSave(m.store, loc.text)
        m.location = settingsLocationLoad(m.store)
        settingsUiRefresh()
    end if
    dialog.close = true
    if choice = 1 then
        m.zipDigits = [0, 0, 0, 0, 0]
        settingsUiZipDigits(0)
    end if
end sub

sub settingsUiZipDigits(focus as integer)
    m.placeMode = "zip"
    names = []
    for i = 0 to 4
        names.push("Digit " + (i + 1).toStr() + ": " + m.zipDigits[i].toStr())
    end for
    names.push("Save ZIP: " + locationZipDigits(m.zipDigits))
    names.push("Cancel")
    settingsUiShowPlaces(names, "ZIP " + locationZipDigits(m.zipDigits) + " - OK cycles each digit 0-9")
    m.places.jumpToItem = focus
    m.top.findNode("hint").text = "Up / down selects a digit. OK changes it. Then choose Save ZIP."
end sub

sub settingsUiZipSelected(selected as integer)
    if selected < 5 then
        m.zipDigits[selected] = (m.zipDigits[selected] + 1) mod 10
        settingsUiZipDigits(selected)
    else if selected = 5 then
        loc = locationZipRead(locationZipDigits(m.zipDigits))
        if loc = invalid then
            m.top.findNode("subtitle").text = "ZIP not found. Change digits, or Cancel and use city / coordinates."
            return
        end if
        settingsLocationSave(m.store, loc.text)
        settingsUiEndPlaces()
    else if selected = 6 then
        settingsUiEndPlaces()
    end if
end sub

sub settingsUiCountries()
    m.countryRows = ParseJson(ReadAsciiFile("pkg:/config/location/countries.json"))
    if m.countryRows = invalid then return
    m.placeMode = "country"
    names = ["Cancel"]
    for each row in m.countryRows
        names.push(row[0])
    end for
    settingsUiShowPlaces(names, "Choose country / territory")
end sub

sub settingsUiShowPlaces(names as object, title as string)
    content = CreateObject("roSGNode", "ContentNode")
    for each name in names
        content.createChild("ContentNode").title = name
    end for
    m.places.content = content
    m.places.jumpToItem = 0
    m.options.visible = false
    m.places.visible = true
    m.top.findNode("subtitle").text = title
    m.places.setFocus(true)
end sub

sub settingsUiPlaceSelected()
    selected = m.places.itemSelected
    if selected < 0 then return
    if m.placeMode = "zip" then
        settingsUiZipSelected(selected)
        return
    end if
    if m.placeMode = "country" then
        if selected = 0 then
            settingsUiEndPlaces()
            return
        end if
        if selected > m.countryRows.count() then return
        country = m.countryRows[selected - 1]
        m.cityRows = ParseJson(ReadAsciiFile("pkg:/config/location/cities-" + country[1] + ".json"))
        if m.cityRows = invalid then return
        m.placeMode = "city"
        names = ["Back to countries"]
        for each city in m.cityRows
            names.push(city[0])
        end for
        settingsUiShowPlaces(names, country[0] + " - choose a nearby city")
    else
        if selected = 0 then
            settingsUiCountries()
            return
        end if
        if selected > m.cityRows.count() then return
        loc = locationCityCoordinates(m.cityRows[selected - 1])
        if loc <> invalid then settingsLocationSave(m.store, loc.text)
        settingsUiEndPlaces()
    end if
end sub

sub settingsUiEndPlaces()
    m.zipDigits = invalid
    m.top.findNode("hint").text = "OK changes a value. Up / down moves. Back saves and exits."
    m.countryRows = invalid
    m.cityRows = invalid
    m.places.content = invalid
    m.places.visible = false
    m.options.visible = true
    m.top.findNode("subtitle").text = "Screensaver settings"
    m.location = settingsLocationLoad(m.store)
    settingsUiRefresh()
    m.options.setFocus(true)
end sub

sub settingsUiCoordinatesSelected(event as object)
    dialog = m.top.dialog
    if event.getData() = 0 then
        if not settingsLocationSave(m.store, dialog.text) then
            dialog.title = "Invalid coordinates"
            dialog.message = ["Enter latitude (-90 to 90), longitude (-180 to 180), separated by a comma."]
            return
        end if
        m.location = settingsLocationLoad(m.store)
        settingsUiRefresh()
    end if
    dialog.close = true
end sub

sub settingsUiDialogClosed()
    if m.places <> invalid and m.places.visible then
        m.places.setFocus(true)
        return
    end if
    if m.top.dialog = invalid then
        m.options.setFocus(true)
    end if
end sub

' Read-only build history. Navigation never changes persisted settings.
sub settingsUiChangelog()
    entry = m.changelogEntries[m.changelogIndex]
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Changelog: " + entry.title
    dialog.message = entry.message
    dialog.bottomMessage = ["Development build history, not Roku Store publication dates."]
    nextLabel = "Next entry"
    if m.changelogIndex = m.changelogEntries.count() - 1 then nextLabel = "Back to newest"
    dialog.buttons = [nextLabel, "Close"]
    dialog.observeField("buttonSelected", "settingsUiChangelogSelected")
    dialog.observeField("wasClosed", "settingsUiDialogClosed")
    m.top.dialog = dialog
end sub

sub settingsUiChangelogSelected(event as object)
    m.top.dialog.close = true
    if event.getData() = 0 then
        m.changelogIndex = (m.changelogIndex + 1) mod m.changelogEntries.count()
        settingsUiChangelog()
    else
        m.changelogEntries = invalid
    end if
end sub
