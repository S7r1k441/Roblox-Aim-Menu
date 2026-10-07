--[[
	ESP Menu (LocalScript)
	Place in: StarterPlayer > StarterPlayerScripts
	Toggle menu: Right Shift (rebindable in Settings tab)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
local Settings = {
	-- ESP
	Enabled = true,
	Highlight = true,
	Names = true,
	Distance = true,
	Health = true,
	Tracers = false,
	TeamCheck = false,
	TeamColor = true,
	MaxDistance = 1000,

	-- Aimbot
	Aimbot = false,
	AimHead = true, -- false = aim at torso (HumanoidRootPart)
	AimTeamCheck = true,
	WallCheck = true,
	ShowFOV = true,
	FOVRadius = 150,
	Smoothness = 5, -- 1 = instant snap, higher = slower

	-- Player
	Fly = false,
	FlySpeed = 60,
	Fullbright = false,
	Noclip = false,

	-- Menu
	Theme = "Crimson",
}

local menuKey = Enum.KeyCode.RightShift
local AIM_KEY = Enum.UserInputType.MouseButton2 -- hold right mouse to aim

---------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------
local rgb = Color3.fromRGB

local Themes = {
	Crimson = {
		Background = rgb(10, 10, 12),
		Element = rgb(20, 18, 20),
		ElementHover = rgb(30, 24, 26),
		Stroke = rgb(48, 22, 26),
		Off = rgb(42, 38, 40),
		Text = rgb(240, 236, 236),
		SubText = rgb(145, 130, 132),
		Accent = rgb(225, 29, 52),
	},
	Midnight = {
		Background = rgb(11, 13, 20),
		Element = rgb(19, 22, 33),
		ElementHover = rgb(27, 31, 46),
		Stroke = rgb(35, 42, 66),
		Off = rgb(40, 45, 62),
		Text = rgb(232, 236, 248),
		SubText = rgb(130, 140, 170),
		Accent = rgb(80, 140, 255),
	},
	Emerald = {
		Background = rgb(10, 14, 12),
		Element = rgb(17, 24, 20),
		ElementHover = rgb(24, 34, 28),
		Stroke = rgb(28, 52, 40),
		Off = rgb(36, 48, 42),
		Text = rgb(232, 245, 238),
		SubText = rgb(125, 155, 140),
		Accent = rgb(40, 210, 125),
	},
	Amethyst = {
		Background = rgb(13, 10, 18),
		Element = rgb(22, 18, 30),
		ElementHover = rgb(31, 25, 42),
		Stroke = rgb(50, 36, 72),
		Off = rgb(45, 38, 58),
		Text = rgb(240, 234, 250),
		SubText = rgb(150, 135, 175),
		Accent = rgb(165, 95, 255),
	},
	Sunset = {
		Background = rgb(14, 11, 9),
		Element = rgb(24, 19, 15),
		ElementHover = rgb(34, 26, 20),
		Stroke = rgb(62, 40, 24),
		Off = rgb(50, 42, 36),
		Text = rgb(248, 240, 232),
		SubText = rgb(170, 145, 125),
		Accent = rgb(255, 135, 40),
	},
	Snow = {
		Background = rgb(244, 244, 247),
		Element = rgb(255, 255, 255),
		ElementHover = rgb(236, 236, 242),
		Stroke = rgb(218, 218, 226),
		Off = rgb(205, 205, 214),
		Text = rgb(25, 25, 32),
		SubText = rgb(115, 115, 130),
		Accent = rgb(225, 29, 52),
	},
}
local ThemeOrder = { "Crimson", "Midnight", "Emerald", "Amethyst", "Sunset", "Snow" }

local theme = Themes[Settings.Theme]
local themed = {} -- { instance, property, themeKey }
local themeCallbacks = {} -- run after every theme change

local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tween(inst, props, info)
	TweenService:Create(inst, info or FAST, props):Play()
end

-- Sets a property from the current theme and keeps it in sync on theme change
local function bind(inst, prop, key)
	table.insert(themed, { inst, prop, key })
	inst[prop] = theme[key]
	return inst
end

local function applyTheme(name)
	theme = Themes[name]
	Settings.Theme = name
	for _, entry in ipairs(themed) do
		local inst, prop, key = entry[1], entry[2], entry[3]
		if inst.Parent then
			tween(inst, { [prop] = theme[key] }, SMOOTH)
		end
	end
	for _, callback in ipairs(themeCallbacks) do
		callback()
	end
end

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------
local connections = {}
local function track(connection)
	table.insert(connections, connection)
	return connection
end

local function create(class, props)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function outline(parent, key)
	local s = create("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
	return bind(s, "Color", key or "Stroke")
end

local function isClick(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------
local ScreenGui = create("ScreenGui", {
	Name = "ESPMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 100,
	Parent = LocalPlayer:WaitForChild("PlayerGui"),
})

local TracerLayer = create("Frame", {
	Name = "Tracers",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Parent = ScreenGui,
})

local WINDOW_SIZE = Vector2.new(540, 380)
local TOPBAR_HEIGHT = 44
local SIDEBAR_WIDTH = 140

local Main = create("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
	ClipsDescendants = true,
	BorderSizePixel = 0,
	Parent = ScreenGui,
})
bind(Main, "BackgroundColor3", "Background")
corner(Main, 10)
outline(Main)

-- Top bar
local Topbar = create("Frame", {
	Name = "Topbar",
	Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT),
	BackgroundTransparency = 1,
	Parent = Main,
})

local TitleRow = create("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -100, 1, 0),
	Parent = Topbar,
})
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
	Parent = TitleRow,
})

local Logo = create("Frame", { Size = UDim2.fromOffset(4, 18), BorderSizePixel = 0, LayoutOrder = 1, Parent = TitleRow })
bind(Logo, "BackgroundColor3", "Accent")
corner(Logo, 2)

local TitleLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 20),
	Font = Enum.Font.GothamBlack,
	TextSize = 16,
	Text = "ESP MENU",
	LayoutOrder = 2,
	Parent = TitleRow,
})
bind(TitleLabel, "TextColor3", "Text")

local KeyHint = create("TextLabel", {
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 20),
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	LayoutOrder = 3,
	Parent = TitleRow,
})
bind(KeyHint, "TextColor3", "SubText")

local function updateKeyHint()
	KeyHint.Text = "[" .. menuKey.Name .. "]"
end
updateKeyHint()

local function topbarButton(text, offset, hoverKey)
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, offset, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Text = text,
		Parent = Topbar,
	})
	bind(button, "TextColor3", "SubText")
	button.MouseEnter:Connect(function()
		tween(button, { TextColor3 = theme[hoverKey] })
	end)
	button.MouseLeave:Connect(function()
		tween(button, { TextColor3 = theme.SubText })
	end)
	return button
end

local CloseButton = topbarButton("×", -10, "Accent")
local MinimizeButton = topbarButton("–", -40, "Text")

-- Accent line under the top bar, fading out to the right
local AccentLine = create("Frame", {
	Position = UDim2.fromOffset(0, TOPBAR_HEIGHT),
	Size = UDim2.new(1, 0, 0, 1),
	BorderSizePixel = 0,
	Parent = Main,
})
bind(AccentLine, "BackgroundColor3", "Accent")
create("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = AccentLine,
})

-- Sidebar
local Sidebar = create("Frame", {
	Position = UDim2.fromOffset(0, TOPBAR_HEIGHT + 1),
	Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -(TOPBAR_HEIGHT + 1)),
	BackgroundTransparency = 1,
	Parent = Main,
})
create("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	Parent = Sidebar,
})
create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = Sidebar })

local SidebarDivider = create("Frame", {
	Position = UDim2.fromOffset(SIDEBAR_WIDTH, TOPBAR_HEIGHT + 1),
	Size = UDim2.new(0, 1, 1, -(TOPBAR_HEIGHT + 1)),
	BorderSizePixel = 0,
	Parent = Main,
})
bind(SidebarDivider, "BackgroundColor3", "Stroke")

local PageHolder = create("Frame", {
	Position = UDim2.fromOffset(SIDEBAR_WIDTH + 1, TOPBAR_HEIGHT + 1),
	Size = UDim2.new(1, -(SIDEBAR_WIDTH + 1), 1, -(TOPBAR_HEIGHT + 1)),
	BackgroundTransparency = 1,
	Parent = Main,
})

-- Dragging (by top bar)
do
	local dragging, dragStart, startPos
	Topbar.InputBegan:Connect(function(input)
		if isClick(input) then
			dragging, dragStart, startPos = true, input.Position, Main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local delta = input.Position - dragStart
			Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
end

-- Minimize / close
do
	local minimized = false
	MinimizeButton.MouseButton1Click:Connect(function()
		minimized = not minimized
		local height = minimized and TOPBAR_HEIGHT or WINDOW_SIZE.Y
		tween(Main, { Size = UDim2.fromOffset(WINDOW_SIZE.X, height) }, SMOOTH)
	end)
	CloseButton.MouseButton1Click:Connect(function()
		Main.Visible = false
	end)
end

---------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------
local tabs = {}

local function selectTab(selected)
	for _, tab in ipairs(tabs) do
		tab.Selected = tab == selected
		tab.Page.Visible = tab.Selected
		tab.Refresh()
	end
end

local function createTab(name)
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = #tabs + 1,
		Parent = Sidebar,
	})
	corner(button, 6)

	local indicator = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		BorderSizePixel = 0,
		Parent = button,
	})
	bind(indicator, "BackgroundColor3", "Accent")
	corner(indicator, 2)

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -14, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = name,
		Parent = button,
	})

	local page = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = PageHolder,
	})
	bind(page, "ScrollBarImageColor3", "Accent")
	create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 14),
		Parent = page,
	})
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = page })

	local tab = { Page = page, Selected = false }

	function tab.Refresh()
		tween(button, {
			BackgroundColor3 = theme.Element,
			BackgroundTransparency = tab.Selected and 0 or 1,
		})
		tween(label, { TextColor3 = tab.Selected and theme.Text or theme.SubText })
		tween(indicator, { Size = UDim2.fromOffset(3, tab.Selected and 16 or 0) })
	end

	button.MouseEnter:Connect(function()
		if not tab.Selected then
			tween(label, { TextColor3 = theme.Text })
		end
	end)
	button.MouseLeave:Connect(tab.Refresh)
	button.MouseButton1Click:Connect(function()
		selectTab(tab)
	end)

	table.insert(tabs, tab)
	table.insert(themeCallbacks, tab.Refresh)
	tab.Refresh()
	return page
end

---------------------------------------------------------------------
-- Elements
---------------------------------------------------------------------
local order = 0
local function nextOrder()
	order += 1
	return order
end

local function hoverable(row)
	row.MouseEnter:Connect(function()
		tween(row, { BackgroundColor3 = theme.ElementHover })
	end)
	row.MouseLeave:Connect(function()
		tween(row, { BackgroundColor3 = theme.Element })
	end)
end

local function makeRow(page, class, height)
	local row = create(class, {
		Size = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		Parent = page,
	})
	if class == "TextButton" then
		row.AutoButtonColor = false
		row.Text = ""
	end
	bind(row, "BackgroundColor3", "Element")
	corner(row, 6)
	outline(row)
	hoverable(row)
	return row
end

local function rowLabel(row, text, yOffset)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, yOffset or 0),
		Size = UDim2.new(1, -24, 0, yOffset and 20 or row.Size.Y.Offset),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		Parent = row,
	})
	bind(label, "TextColor3", "Text")
	return label
end

local function makeSection(page, text)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = string.upper(text),
		LayoutOrder = nextOrder(),
		Parent = page,
	})
	bind(label, "TextColor3", "SubText")
end

local function makeToggle(page, text, key)
	local row = makeRow(page, "TextButton", 36)
	local label = rowLabel(row, text)

	local switch = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(36, 18),
		BorderSizePixel = 0,
		Parent = row,
	})
	corner(switch, 9)

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = switch,
	})
	corner(knob, 7)

	local function refresh()
		local on = Settings[key]
		tween(switch, { BackgroundColor3 = on and theme.Accent or theme.Off })
		tween(knob, { Position = on and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
		tween(label, { TextColor3 = on and theme.Text or theme.SubText })
	end
	refresh()
	table.insert(themeCallbacks, refresh)

	row.MouseButton1Click:Connect(function()
		Settings[key] = not Settings[key]
		refresh()
	end)
end

local function makeSlider(page, text, key, min, max, step, suffix)
	local row = makeRow(page, "Frame", 52)
	rowLabel(row, text, 8)

	local valueLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(80, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	bind(valueLabel, "TextColor3", "Accent")

	local bar = create("Frame", {
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 4),
		BorderSizePixel = 0,
		Parent = row,
	})
	bind(bar, "BackgroundColor3", "Off")
	corner(bar, 2)

	local fill = create("Frame", { BorderSizePixel = 0, Parent = bar })
	bind(fill, "BackgroundColor3", "Accent")
	corner(fill, 2)

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BorderSizePixel = 0,
		Parent = bar,
	})
	bind(knob, "BackgroundColor3", "Text")
	corner(knob, 6)

	local function refresh()
		local alpha = (Settings[key] - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = tostring(Settings[key]) .. (suffix or "")
	end
	refresh()

	local sliding = false
	local function setFromX(x)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local value = min + (max - min) * alpha
		Settings[key] = math.clamp(math.floor(value / step + 0.5) * step, min, max)
		refresh()
	end

	row.InputBegan:Connect(function(input)
		if isClick(input) then
			sliding = true
			setFromX(input.Position.X)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if sliding and isMove(input) then
			setFromX(input.Position.X)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if isClick(input) then
			sliding = false
		end
	end))
end

local function makeButton(page, text, callback)
	local row = makeRow(page, "TextButton", 36)
	local label = rowLabel(row, text)
	label.TextXAlignment = Enum.TextXAlignment.Center
	row.MouseButton1Click:Connect(callback)
	return row, label
end

local onKeyCaptured -- set while waiting for a new menu key

local function makeKeybind(page, text)
	local row = makeRow(page, "TextButton", 36)
	rowLabel(row, text)

	local keyBox = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Text = menuKey.Name,
		Parent = row,
	})
	bind(keyBox, "BackgroundColor3", "Background")
	bind(keyBox, "TextColor3", "Accent")
	corner(keyBox, 4)
	outline(keyBox)
	create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = keyBox })

	row.MouseButton1Click:Connect(function()
		keyBox.Text = "press a key..."
		onKeyCaptured = function(keyCode)
			if keyCode ~= Enum.KeyCode.Escape then
				menuKey = keyCode
				updateKeyHint()
			end
			keyBox.Text = menuKey.Name
		end
	end)
end

local function makeThemePicker(page)
	local refreshers = {}

	for _, name in ipairs(ThemeOrder) do
		local colors = Themes[name]
		local row = makeRow(page, "TextButton", 40)
		local label = rowLabel(row, name)
		label.Position = UDim2.fromOffset(78, 0)

		-- Preview swatches (fixed colors of that theme)
		local swatches = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0, 60, 1, 0),
			Parent = row,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, -4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = swatches,
		})
		for i, colorKey in ipairs({ "Background", "Element", "Accent" }) do
			local swatch = create("Frame", {
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = colors[colorKey],
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = i,
				Parent = swatches,
			})
			corner(swatch, 9)
			create("UIStroke", { Color = colors.Stroke, Thickness = 1.5, Parent = swatch })
		end

		local check = create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(60, 20),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "ACTIVE",
			Parent = row,
		})
		bind(check, "TextColor3", "Accent")

		local rowStroke = row:FindFirstChildOfClass("UIStroke")
		table.insert(refreshers, function()
			local active = Settings.Theme == name
			check.Visible = active
			tween(rowStroke, { Color = active and theme.Accent or theme.Stroke }, SMOOTH)
		end)

		row.MouseButton1Click:Connect(function()
			applyTheme(name)
		end)
	end

	local function refreshAll()
		for _, refresh in ipairs(refreshers) do
			refresh()
		end
	end
	refreshAll()
	table.insert(themeCallbacks, refreshAll)
end

---------------------------------------------------------------------
-- Build menu
---------------------------------------------------------------------
local espPage = createTab("ESP")
local aimPage = createTab("Aimbot")
local playerPage = createTab("Player")
local settingsPage = createTab("Settings")

makeSection(espPage, "General")
makeToggle(espPage, "ESP Enabled", "Enabled")
makeToggle(espPage, "Highlight", "Highlight")
makeToggle(espPage, "Tracers", "Tracers")
makeSection(espPage, "Info")
makeToggle(espPage, "Names", "Names")
makeToggle(espPage, "Distance", "Distance")
makeToggle(espPage, "Health", "Health")
makeSection(espPage, "Filters")
makeToggle(espPage, "Team Check", "TeamCheck")
makeToggle(espPage, "Use Team Colors", "TeamColor")
makeSlider(espPage, "Max Distance", "MaxDistance", 50, 5000, 50, " studs")

makeSection(aimPage, "General (hold right mouse)")
makeToggle(aimPage, "Aimbot Enabled", "Aimbot")
makeToggle(aimPage, "Aim at Head", "AimHead")
makeSection(aimPage, "Checks")
makeToggle(aimPage, "Team Check", "AimTeamCheck")
makeToggle(aimPage, "Wall Check", "WallCheck")
makeSection(aimPage, "Tuning")
makeToggle(aimPage, "Show FOV Circle", "ShowFOV")
makeSlider(aimPage, "FOV Radius", "FOVRadius", 25, 600, 5, " px")
makeSlider(aimPage, "Smoothness", "Smoothness", 1, 20, 1)

makeSection(playerPage, "Movement (WASD, Space up, Ctrl down)")
makeToggle(playerPage, "Fly", "Fly")
makeSlider(playerPage, "Fly Speed", "FlySpeed", 10, 300, 5)
makeToggle(playerPage, "Noclip", "Noclip")
makeSection(playerPage, "World")
makeToggle(playerPage, "Fullbright", "Fullbright")

makeSection(settingsPage, "Theme")
makeThemePicker(settingsPage)
makeSection(settingsPage, "Menu")
makeKeybind(settingsPage, "Menu Key")
local unloadButton, unloadLabel = makeButton(settingsPage, "Unload Menu", function() end)
bind(unloadLabel, "TextColor3", "Accent")

selectTab(tabs[1])

-- FOV circle
local FOVCircle = create("Frame", {
	Name = "FOVCircle",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = ScreenGui,
})
corner(FOVCircle, 9999)
local fovStroke = create("UIStroke", { Transparency = 0.25, Thickness = 1.5, Parent = FOVCircle })
bind(fovStroke, "Color", "Accent")

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if onKeyCaptured then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local callback = onKeyCaptured
			onKeyCaptured = nil
			callback(input.KeyCode)
		end
		return
	end
	if gameProcessed then return end
	if input.KeyCode == menuKey then
		Main.Visible = not Main.Visible
	end
end))

---------------------------------------------------------------------
-- ESP
---------------------------------------------------------------------
local espObjects = {} -- [Player] = { Highlight, Billboard, Label, Tracer }

local function getColor(player)
	if Settings.TeamColor and player.Team then
		return player.TeamColor.Color
	end
	return theme.Accent
end

local function removeESP(player)
	local objs = espObjects[player]
	if not objs then return end
	for _, obj in pairs(objs) do
		obj:Destroy()
	end
	espObjects[player] = nil
end

local function createESP(player)
	removeESP(player)

	local highlight = create("Highlight", {
		FillTransparency = 0.6,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Enabled = false,
		Parent = ScreenGui,
	})

	local billboard = create("BillboardGui", {
		Size = UDim2.fromOffset(200, 50),
		StudsOffset = Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = ScreenGui,
	})

	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextStrokeTransparency = 0.4,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Parent = billboard,
	})

	local tracer = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Visible = false,
		Parent = TracerLayer,
	})

	espObjects[player] = {
		Highlight = highlight,
		Billboard = billboard,
		Label = label,
		Tracer = tracer,
	}
end

local function hideESP(objs)
	objs.Highlight.Enabled = false
	objs.Billboard.Enabled = false
	objs.Tracer.Visible = false
end

local function updateTracer(tracer, from, to, color)
	local delta = to - from
	local mid = (from + to) / 2
	tracer.Position = UDim2.fromOffset(mid.X, mid.Y)
	tracer.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
	tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	tracer.BackgroundColor3 = color
	tracer.Visible = true
end

track(RunService.RenderStepped:Connect(function()
	Camera = workspace.CurrentCamera
	local myChar = LocalPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local viewport = Camera.ViewportSize
	local tracerOrigin = Vector2.new(viewport.X / 2, viewport.Y)

	for player, objs in pairs(espObjects) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local head = char and char:FindFirstChild("Head")

		local show = Settings.Enabled and root and humanoid and humanoid.Health > 0
		if show and Settings.TeamCheck and player.Team and player.Team == LocalPlayer.Team then
			show = false
		end

		local distance = 0
		if show then
			distance = myRoot and (myRoot.Position - root.Position).Magnitude or (Camera.CFrame.Position - root.Position).Magnitude
			if distance > Settings.MaxDistance then
				show = false
			end
		end

		if not show then
			hideESP(objs)
			continue
		end

		local color = getColor(player)

		-- Highlight
		objs.Highlight.Adornee = char
		objs.Highlight.FillColor = color
		objs.Highlight.OutlineColor = color
		objs.Highlight.Enabled = Settings.Highlight

		-- Text (name / distance / health)
		local lines = {}
		if Settings.Names then
			table.insert(lines, player.DisplayName)
		end
		local info = {}
		if Settings.Distance then
			table.insert(info, string.format("%dm", distance))
		end
		if Settings.Health then
			table.insert(info, string.format("%d HP", math.floor(humanoid.Health)))
		end
		if #info > 0 then
			table.insert(lines, table.concat(info, " | "))
		end

		objs.Billboard.Adornee = head or root
		objs.Label.Text = table.concat(lines, "\n")
		objs.Label.TextColor3 = color
		objs.Billboard.Enabled = #lines > 0

		-- Tracer
		if Settings.Tracers then
			local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
			if onScreen then
				updateTracer(objs.Tracer, tracerOrigin, Vector2.new(screenPos.X, screenPos.Y), color)
			else
				objs.Tracer.Visible = false
			end
		else
			objs.Tracer.Visible = false
		end
	end
end))

---------------------------------------------------------------------
-- Aimbot
---------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function isVisible(part, targetChar)
	local origin = Camera.CFrame.Position
	rayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
	local result = workspace:Raycast(origin, part.Position - origin, rayParams)
	return result == nil or result.Instance:IsDescendantOf(targetChar)
end

local function getTarget(mousePos)
	local best, bestDist = nil, Settings.FOVRadius
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if Settings.AimTeamCheck and player.Team and player.Team == LocalPlayer.Team then continue end

		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local part = char and (Settings.AimHead and char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
		if not (part and humanoid and humanoid.Health > 0) then continue end

		local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen then continue end

		local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
		if dist < bestDist and (not Settings.WallCheck or isVisible(part, char)) then
			best, bestDist = part, dist
		end
	end
	return best
end

-- Runs right after the default camera script so our adjustment isn't overwritten
RunService:BindToRenderStep("ESPMenuAimbot", Enum.RenderPriority.Camera.Value + 1, function()
	Camera = workspace.CurrentCamera
	local mousePos = UserInputService:GetMouseLocation()

	FOVCircle.Visible = Settings.Aimbot and Settings.ShowFOV
	FOVCircle.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
	FOVCircle.Size = UDim2.fromOffset(Settings.FOVRadius * 2, Settings.FOVRadius * 2)

	if not Settings.Aimbot or not UserInputService:IsMouseButtonPressed(AIM_KEY) then return end

	local target = getTarget(mousePos)
	if not target then return end

	local camPos = Camera.CFrame.Position
	local goal = CFrame.lookAt(camPos, target.Position)
	Camera.CFrame = Camera.CFrame:Lerp(goal, 1 / Settings.Smoothness)
end)

---------------------------------------------------------------------
-- Fullbright
---------------------------------------------------------------------
local Lighting = game:GetService("Lighting")

local FULLBRIGHT = {
	Brightness = 2,
	ClockTime = 14,
	FogEnd = 1e6,
	FogStart = 1e6,
	GlobalShadows = false,
	Ambient = Color3.fromRGB(178, 178, 178),
	OutdoorAmbient = Color3.fromRGB(178, 178, 178),
}

local savedLighting -- original values, restored when fullbright turns off
local savedAtmospheres = {} -- [Atmosphere] = original Density

local function enableFullbright()
	if not savedLighting then
		savedLighting = {}
		for prop in pairs(FULLBRIGHT) do
			savedLighting[prop] = Lighting[prop]
		end
	end

	-- Reapplied every frame in case the game changes lighting itself
	for prop, value in pairs(FULLBRIGHT) do
		if Lighting[prop] ~= value then
			Lighting[prop] = value
		end
	end

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") then
			if savedAtmospheres[child] == nil then
				savedAtmospheres[child] = child.Density
			end
			child.Density = 0
		end
	end
end

local function disableFullbright()
	if not savedLighting then return end
	for prop, value in pairs(savedLighting) do
		Lighting[prop] = value
	end
	for atmosphere, density in pairs(savedAtmospheres) do
		if atmosphere.Parent then
			atmosphere.Density = density
		end
	end
	savedLighting = nil
	savedAtmospheres = {}
end

track(RunService.RenderStepped:Connect(function()
	if Settings.Fullbright then
		enableFullbright()
	else
		disableFullbright()
	end
end))

---------------------------------------------------------------------
-- Noclip
---------------------------------------------------------------------
local noclipParts = {} -- [BasePart] = original CanCollide

local function restoreCollisions()
	for part, canCollide in pairs(noclipParts) do
		if part.Parent then
			part.CanCollide = canCollide
		end
	end
	noclipParts = {}
end

-- Stepped runs before physics, so collisions are off when the step simulates
track(RunService.Stepped:Connect(function()
	if not Settings.Noclip then
		if next(noclipParts) then
			restoreCollisions()
		end
		return
	end

	local char = LocalPlayer.Character
	if not char then return end

	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			if noclipParts[part] == nil then
				noclipParts[part] = true
			end
			part.CanCollide = false
		end
	end
end))

---------------------------------------------------------------------
-- Fly
---------------------------------------------------------------------
local flyAttachment, flyVelocity, flyGyro

local function stopFly()
	if not flyAttachment then return end
	flyAttachment:Destroy()
	flyAttachment, flyVelocity, flyGyro = nil, nil, nil

	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function startFly(root)
	flyAttachment = create("Attachment", { Name = "FlyAttachment", Parent = root })
	flyVelocity = create("LinearVelocity", {
		Attachment0 = flyAttachment,
		MaxForce = math.huge,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		VectorVelocity = Vector3.zero,
		Parent = flyAttachment,
	})
	flyGyro = create("AlignOrientation", {
		Attachment0 = flyAttachment,
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		RigidityEnabled = true,
		CFrame = root.CFrame.Rotation,
		Parent = flyAttachment,
	})
end

local function getFlyDirection(humanoid)
	local camCF = Camera.CFrame
	local move = Vector3.zero

	if not UserInputService:GetFocusedTextBox() then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += camCF.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= camCF.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += camCF.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= camCF.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
	end

	-- Fallback for mobile / gamepad thumbsticks
	if move.Magnitude == 0 then
		move = humanoid.MoveDirection
	end

	return move.Magnitude > 0 and move.Unit or Vector3.zero
end

track(RunService.RenderStepped:Connect(function()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")

	if not (Settings.Fly and root and humanoid and humanoid.Health > 0) then
		stopFly()
		return
	end

	-- (Re)create after toggling on or respawning
	if not flyAttachment or flyAttachment.Parent ~= root then
		stopFly()
		startFly(root)
	end

	humanoid.PlatformStand = true
	flyVelocity.VectorVelocity = getFlyDirection(humanoid) * Settings.FlySpeed
	flyGyro.CFrame = Camera.CFrame.Rotation
end))

---------------------------------------------------------------------
-- Player tracking
---------------------------------------------------------------------
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		createESP(player)
	end
end

track(Players.PlayerAdded:Connect(createESP))
track(Players.PlayerRemoving:Connect(removeESP))

---------------------------------------------------------------------
-- Unload
---------------------------------------------------------------------
unloadButton.MouseButton1Click:Connect(function()
	RunService:UnbindFromRenderStep("ESPMenuAimbot")
	stopFly()
	disableFullbright()
	restoreCollisions()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	for player in pairs(espObjects) do
		removeESP(player)
	end
	ScreenGui:Destroy()
end)
