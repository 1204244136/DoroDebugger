#Requires AutoHotkey v2.0
#SingleInstance Force

; --- 全局变量定义 ---
Global MyGui                    := "" ; GUI 对象
Global gFocusedProgramEdit      := "" ; 聚焦窗口编辑框
Global gCalculatedCoordsEdit    := "" ; 换算坐标编辑框 (可编辑)
Global gStatusText              := "" ; 状态信息文本
Global gMouseCoordsEdit         := "" ; 鼠标屏幕坐标显示框
Global gRelativeMouseCoordsEdit := "" ; 鼠标窗口相对坐标显示框
Global gClientAreaEdit          := "" ; 客户区矩形显示框
Global gPixelColorEdit          := "" ; 位置颜色显示框 (十六进制)
Global gPixelCharacterBlock     := "" ; 显示颜色字符的 Text 控件
Global gSelectedRefWidth        := 3840 ; 默认目标宽度 (4K)
Global gSelectedRefHeight       := 2160 ; 默认目标高度 (4K)
Global gTargethWnd              := "" ; 存储上次记录的目标窗口句柄

; --- 目标分辨率映射表 ---
resolutions := Map(
    "4K", [3840, 2160],
    "2K", [2560, 1440],
    "1080p", [1920, 1080]
)
defaultRefKey := "4K"

; --- 获取当前屏幕分辨率 ---
currentW := A_ScreenWidth
currentH := A_ScreenHeight
currentResText := "当前屏幕分辨率: " . currentW . "x" . currentH

; --- 创建图形用户界面 (GUI) ---
MyGui := Gui("+AlwaysOnTop")
MyGui.Title := "DDB v1.0"

; 提示信息
MyGui.Add("Text", "xm y+10", "注意：标题栏和边框均不属于客户区")

; --- 行 1: 当前分辨率 ---
MyGui.Add("Text", "xm y+10", currentResText)

; --- 行 2: 目标分辨率 ---
MyGui.Add("Text", "xm y+15", "目标分辨率:")
radio4k := MyGui.Add("Radio", "x+m yp vSelectedResName Checked Group", "4K")
radio2k := MyGui.Add("Radio", "x+m yp", "2K")
radio1080p := MyGui.Add("Radio", "x+m yp", "1080p")

; --- 行 3: 聚焦窗口 ---
MyGui.Add("Text", "xm y+15", "聚焦窗口:")
gFocusedProgramEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left")

; --- 行 4: 屏幕位置 ---
MyGui.Add("Text", "xm y+10", "屏幕位置:")
gMouseCoordsEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left")

; --- 行 5: 窗口位置 ---
MyGui.Add("Text", "xm y+10", "窗口位置:")
gRelativeMouseCoordsEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left")

; --- 行 6: 客户区矩形 ---
MyGui.Add("Text", "xm y+10", "客户区:  ") ; 注意标签后的空格是用户特意加的
gClientAreaEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left")

; --- 行 7: 位置颜色 & 复制按钮 & 颜色字符 ---
MyGui.Add("Text", "xm y+10", "位置颜色:") ; 标签
gPixelColorEdit := MyGui.Add("Edit", "x+m yp w100 ReadOnly Left") ; 显示框
copyColorButton := MyGui.Add("Button", "x+m yp", "复制") ; 复制按钮
copyColorButton.OnEvent("Click", CopyPixelColor)
; 使用带颜色的文本字符 '■' 显示颜色，初始为灰色
myGui.SetFont("s12") 
gPixelCharacterBlock := MyGui.Add("Text", "x+m yp c808080", "■")
myGui.SetFont("") 


; --- 行 8: 换算坐标 & 复制按钮 & 跳转按钮 ---
MyGui.Add("Text", "xm y+10", "换算坐标:")
gCalculatedCoordsEdit := MyGui.Add("Edit", "x+m yp w100 Left", "") ; 允许输入
copyCoordsButton := MyGui.Add("Button", "x+m yp", "复制")
copyCoordsButton.OnEvent("Click", CopyCalculatedCoords)
jumpButton := MyGui.Add("Button", "y+10", "跳转") ; 跳转按钮另起一行
jumpButton.OnEvent("Click", JumpToCoords)

; --- 行 9: 状态信息 ---
gStatusText := MyGui.Add("Text", "xm y+10 w300 vStatusMessage", "按 Ctrl+Alt+Q 获取鼠标信息") ; 初始提示

; --- 绑定其他 GUI 事件 ---
radio4k.OnEvent("Click", ResolutionChange)
radio2k.OnEvent("Click", ResolutionChange)
radio1080p.OnEvent("Click", ResolutionChange)
MyGui.OnEvent("Close", GuiClose)

; --- 显示 GUI ---
MyGui.Show()

; ==============================================================================
; --- 函数定义 ---
; ==============================================================================

; --- GUI 事件处理: 分辨率选择变化 ---
ResolutionChange(GuiCtrlObj, Info) {
    global gSelectedRefWidth, gSelectedRefHeight, gStatusText, resolutions
    selectedName := MyGui["SelectedResName"].Value
    logMsg := ""
    if RegExMatch(selectedName, "^\w+", &match) {
        selectedKey := match[0]
        if resolutions.Has(selectedKey) {
            gSelectedRefWidth := resolutions[selectedKey][1]
            gSelectedRefHeight := resolutions[selectedKey][2]
            logMsg := "目标分辨率已更改为 " . selectedKey . " (" . gSelectedRefWidth . "x" . gSelectedRefHeight . ")"
            gStatusText.Value := logMsg
        }
    }
}

; --- 热键定义: Ctrl+Alt+Q ---
; --- 热键定义: Ctrl+Alt+Q ---
^!Q:: {
    ; 引用全局变量
    global MyGui, gFocusedProgramEdit, gCalculatedCoordsEdit, gStatusText, gSelectedRefWidth, gSelectedRefHeight, gMouseCoordsEdit, gRelativeMouseCoordsEdit, gClientAreaEdit, gTargethWnd, gPixelColorEdit, gPixelCharacterBlock
    ; 定义局部变量
    local hWnd, progName, winTitle, displayProgInfo, mX, mY, winX, winY, winW, relX, relY, propX, propY, finalX, finalY, isInside := False
    local pixelColorRGB, strColor, sixDigitColor

    ; 检查 gPixelCharacterBlock 是否有效 (保留)
    if !IsObject(gPixelCharacterBlock) {
        MsgBox("脚本错误: 颜色字符控件 'gPixelCharacterBlock' 未初始化。" . "请检查 GUI 创建部分代码是否正确执行。", "初始化错误", "IconError")
        Return
    }

    ; 强制坐标模式
    CoordMode "Mouse", "Screen"
    CoordMode "Pixel", "Screen"

    ; 清空或重置显示字段
    gCalculatedCoordsEdit.Value := ""
    gRelativeMouseCoordsEdit.Value := ""
    gStatusText.Value := "正在处理..."
    gMouseCoordsEdit.Value := ""
    gClientAreaEdit.Value := ""
    gPixelColorEdit.Value := ""
    ; --- ↓↓↓ 直接重置颜色，不再使用 try-catch ↓↓↓ ---
    gPixelCharacterBlock.Opt("c808080") ; 重置字符颜色为灰色 (依赖上面的 IsObject 检查)

    ; 获取当前活动窗口
    hWnd := WinActive("A")
    if (!hWnd) {
        gStatusText.Value := "错误: 未找到活动窗口。"
        gFocusedProgramEdit.Value := "N/A"
        gTargethWnd := ""
        gPixelCharacterBlock.Opt("c808080") ; ★★★ 直接重置 ★★★
        Return
    }
    gTargethWnd := hWnd

    ; 获取并显示窗口信息
    progName := WinGetProcessName("A")
    winTitle := WinGetTitle("A")
    displayProgInfo := progName ? progName : (winTitle ? winTitle : "N/A")
    gFocusedProgramEdit.Value := displayProgInfo

    ; 获取并显示鼠标屏幕坐标
    MouseGetPos(&mX, &mY)
    gMouseCoordsEdit.Value := mX . ", " . mY

    ; 获取并显示像素颜色 及 更新颜色字符 (保留此处的 try-catch)
    try {
        pixelColorRGB := PixelGetColor(mX, mY, "RGB")
        sixDigitColor := Format("{:06X}", pixelColorRGB)
        strColor := "0x" . sixDigitColor
        gPixelCharacterBlock.Opt("c" . sixDigitColor) ; 设置字符颜色
        gPixelColorEdit.Value := strColor
    } catch Error as e {
        gPixelColorEdit.Value := "获取失败: " e.Message
        gPixelCharacterBlock.Opt("c808080") ; ★★★ 直接重置 ★★★
    }

    ; 获取并显示窗口客户区信息 (保留此处的 try-catch)
    try {
        WinGetClientPos(&winX, &winY, &winW, &winH, hWnd)
        gClientAreaEdit.Value := Format("{},{}  {}x{}", winX, winY, winW, winH)
    } catch Error as e {
        gStatusText.Value := "错误: 获取客户区失败 - " . e.Message
        gClientAreaEdit.Value := "Error"
        gPixelCharacterBlock.Opt("c808080") ; ★★★ 直接重置 ★★★
        Return
    }

    ; 检查窗口尺寸是否有效
    if (winW <= 0 or winH <= 0) {
        gStatusText.Value := "错误: 无效窗口尺寸 W:" . winW . ", H:" . winH
        gClientAreaEdit.Value := Format("{},{}  {}x{}", winX, winY, winW, winH)
        gPixelCharacterBlock.Opt("c808080") ; ★★★ 直接重置 ★★★
        Return
    }

    ; 进行边界检查
    isInside := (mX >= winX and mX < (winX + winW) and mY >= winY and mY < (winY + winH))

    ; 根据边界检查结果进行计算和显示
    if (isInside) {
        relX := mX - winX
        relY := mY - winY
        gRelativeMouseCoordsEdit.Value := relX . ", " . relY

        propX := relX / winW
        propY := relY / winH
        finalX := Round(propX * gSelectedRefWidth)
        finalY := Round(propY * gSelectedRefHeight)
        gCalculatedCoordsEdit.Value := finalX . ", " . finalY

        gStatusText.Value := "边界检查: 内部"
    } else {
        gRelativeMouseCoordsEdit.Value := "N/A"
        gCalculatedCoordsEdit.Value := ""
        gStatusText.Value := "边界检查: 外部(请重新聚焦鼠标)"
    }
} ; 热键函数结束 ; 热键函数结束

; --- 跳转按钮点击处理函数 ---
JumpToCoords(GuiCtrlObj, Info) {
    ; 引用全局变量
    global MyGui, gCalculatedCoordsEdit, gStatusText, gSelectedRefWidth, gSelectedRefHeight, gTargethWnd

    ; 定义局部变量
    local targetX, targetY, propX, propY, desiredRelX, desiredRelY, finalScreenX, finalScreenY
    local hWnd, winX, winY, winW, winH
    local inputText, match

    gStatusText.Value := "正在处理跳转..."

    ; 检查并使用存储的目标窗口句柄
    if (!gTargethWnd or !WinExist("ahk_id " . gTargethWnd)) {
        gStatusText.Value := "错误: 请先用 Ctrl+Alt+Q 记录一个有效的目标窗口。"
        gTargethWnd := ""
        Return
    }
    hWnd := gTargethWnd

    ; 获取并验证用户输入的坐标
    inputText := gCalculatedCoordsEdit.Value
    if (!RegExMatch(inputText, "^\s*(-?\d+)\s*[,; ]\s*(-?\d+)\s*$", &match)) {
        gStatusText.Value := "错误: 无效坐标格式 (请输入 X, Y)"
        Return
    }
    targetX := Integer(match[1])
    targetY := Integer(match[2])

    ; 可选: 检查输入坐标范围
    if (targetX < 0 or targetX >= gSelectedRefWidth or targetY < 0 or targetY >= gSelectedRefHeight) {
        gStatusText.Value := "提示: 输入坐标可能超出目标分辨率范围。"
    }

    ; 获取目标窗口的客户区信息
    try {
        WinGetClientPos(&winX, &winY, &winW, &winH, hWnd)
        if (winW <= 0 or winH <= 0) {
            throw Error("无效窗口尺寸 W:" . winW . ", H:" . winH)
        }
    } catch Error as e {
        gStatusText.Value := "错误: 获取目标窗口客户区失败 - " . e.Message
        Return
    }

    ; 执行反向换算
    if (gSelectedRefWidth <= 0 or gSelectedRefHeight <= 0) {
         gStatusText.Value := "错误: 无效的目标分辨率尺寸用于计算。"
         Return
    }
    propX := targetX / gSelectedRefWidth
    propY := targetY / gSelectedRefHeight
    desiredRelX := propX * winW
    desiredRelY := propY * winH
    finalScreenX := Round(winX + desiredRelX)
    finalScreenY := Round(winY + desiredRelY)

    ; 尝试重新激活目标窗口
    try {
        WinActivate("ahk_id " . hWnd)
        Sleep 100
    } catch Error as e {
        gStatusText.Value := "警告: 激活目标窗口失败 - " e.Message "，仍尝试跳转。"
    }

    ; 移动鼠标
    CoordMode "Mouse", "Screen"
    MouseMove finalScreenX, finalScreenY, 0

    ; 更新状态
    gStatusText.Value := "鼠标已跳转至目标窗口对应坐标: " . finalScreenX . ", " . finalScreenY
}

; --- GUI 关闭处理函数 ---
GuiClose(GuiObj) {
    ExitApp()
}

; --- 复制按钮事件处理函数 ---
CopyPixelColor(GuiCtrlObj, Info) {
    global gPixelColorEdit, gStatusText
    local colorValue

    colorValue := gPixelColorEdit.Value
    if (colorValue != "" && colorValue != "获取失败") { ; 检查是否有有效内容
        A_Clipboard := colorValue
        gStatusText.Value := "颜色值 '" colorValue "' 已复制!"
        SetTimer(() => (gStatusText.Value == "颜色值 '" colorValue "' 已复制!" ? gStatusText.Value := "" : ""), -2000)
    } else {
        gStatusText.Value := "没有有效颜色值可复制。"
        SetTimer(() => (gStatusText.Value == "没有有效颜色值可复制。" ? gStatusText.Value := "" : ""), -2000)
    }
}

CopyCalculatedCoords(GuiCtrlObj, Info) {
    global gCalculatedCoordsEdit, gStatusText
    local coordsValue

    coordsValue := gCalculatedCoordsEdit.Value
    if (coordsValue != "") {
        A_Clipboard := coordsValue
        gStatusText.Value := "换算坐标 '" coordsValue "' 已复制!"
        SetTimer(() => (gStatusText.Value == "换算坐标 '" coordsValue "' 已复制!" ? (gStatusText.Value := "") : ""), -2000)
    } else {
        gStatusText.Value := "没有换算坐标可复制。"
        SetTimer(() => (gStatusText.Value == "没有换算坐标可复制。" ? (gStatusText.Value := "") : ""), -2000)
    }
}