#Requires AutoHotkey v2.0
#SingleInstance Force
; --- 全局变量定义 ---
global MyGui := "" ; GUI 对象
global gFocusedProgramEdit := "" ; 聚焦窗口编辑框
global gCalculatedCoordsEdit := "" ; 换算坐标编辑框 (可编辑)
global gCalculatedAreaEdit := "" ; 换算区域编辑框
global gStatusText := "" ; 状态信息文本
global gMouseCoordsEdit := "" ; 鼠标屏幕坐标显示框
global gRelativeMouseCoordsEdit := "" ; 鼠标窗口相对坐标显示框
global gClientAreaEdit := "" ; 客户区矩形显示框
global gPixelColorEdit := "" ; 位置颜色显示框 (十六进制)
global gPixelCharacterBlock := "" ; 显示颜色字符的 Text 控件
global gSelectedRefWidth := 3840 ; 默认目标宽度 (4K)
global gSelectedRefHeight := 2160 ; 默认目标高度 (4K)
global gTargethWnd := "" ; 存储上次记录的目标窗口句柄
global borderGuis := [] ; 用于截图模式的红色边框GUI
global gSelectionRatioEdit := "" ; 选区相对比例编辑框
global gOriginalNikkeAreaEdit := "" ; 原始识图区域输入框 (用于显示模板)
global gCompressedNikkeAreaEdit := "" ; 压缩后识图区域输出框 (X1,Y1,X2,Y2)
; === 新增全局变量: 用于存储实际捕获的 Nikke 区域数值 ===
global gActualNikkeX := 0
global gActualNikkeY := 0
global gActualNikkeW := 0
global gActualNikkeH := 0
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
; --- GUI 布局常量 ---
MyGuiWidth := 300
ButtonWidth := 50
; --- 创建图形用户界面 (GUI) ---
MyGui := Gui("+AlwaysOnTop")
MyGui.Title := "DDB v1.1"
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
gFocusedProgramEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left", "")
; --- 行 4: 屏幕位置 ---
MyGui.Add("Text", "xm y+10", "屏幕位置:")
gMouseCoordsEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left", "")
; --- 行 5: 窗口位置 ---
MyGui.Add("Text", "xm y+10", "窗口位置:")
gRelativeMouseCoordsEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left", "")
; --- 行 6: 客户区矩形 ---
MyGui.Add("Text", "xm y+10", "客户区:  ") ; 注意标签后的空格是用户特意加的
gClientAreaEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left", "")
; --- 行 7: 位置颜色 & 复制按钮 & 颜色字符 ---
MyGui.Add("Text", "xm y+10", "位置颜色:") ; 标签
gPixelColorEdit := MyGui.Add("Edit", "x+m yp w100 ReadOnly Left", "") ; 显示框
copyColorButton := MyGui.Add("Button", "x+m yp w" . ButtonWidth, "复制") ; 复制按钮
copyColorButton.OnEvent("Click", CopyPixelColor)
MyGui.SetFont("s12")
gPixelCharacterBlock := MyGui.Add("Text", "x+m yp c808080", "■")
MyGui.SetFont("")
; --- 行 8: 换算坐标 & 复制按钮 & 跳转按钮 ---
MyGui.Add("Text", "xm y+10", "换算坐标:")
gCalculatedCoordsEdit := MyGui.Add("Edit", "x+m yp w100 Left", "") ; 允许输入
; 计算 '复制' 按钮的 X 位置，使其与 '跳转' 按钮隔开
copyCoordsButton := MyGui.Add("Button", "yp w" . ButtonWidth, "复制") ; 稍微左移，增加间距
copyCoordsButton.OnEvent("Click", CopyCalculatedCoords)
jumpButton := MyGui.Add("Button", "yp w" . ButtonWidth, "跳转")
jumpButton.OnEvent("Click", JumpToCoords)
; --- 行 9: 换算区域 (新添加) ---
MyGui.Add("Text", "xm y+10", "换算区域:")
gCalculatedAreaEdit := MyGui.Add("Edit", "x+m yp Left", "")
gCalculatedAreaEdit.OnEvent("Change", CalculatedAreaChanged) ; 监听变化事件
checkAreaButton := MyGui.Add("Button", "yp w" . ButtonWidth, "检查")
checkAreaButton.OnEvent("Click", CheckCalculatedArea)
; --- 新增行: 选区相对比例 ---
MyGui.Add("Text", "xm y+10", "选区相对比例:")
gSelectionRatioEdit := MyGui.Add("Edit", "x+m yp w150 ReadOnly Left", "")
; --- 新增部分: 识图区域压缩 ---
MyGui.Add("Text", "xm y+10", "--- 识图区域压缩 ---")
MyGui.Add("Text", "xm y+5", "原识图区域:")
gOriginalNikkeAreaEdit := MyGui.Add("Edit", "x+m yp w200 H20 Left", "NikkeX, NikkeY, NikkeX + NikkeW, NikkeY + NikkeH")
MyGui.Add("Text", "xm y+5", "压缩后识图区域:")
gCompressedNikkeAreaEdit := MyGui.Add("Edit", "x+m yp w100 ReadOnly Left", "")
copyCompressedAreaButton := MyGui.Add("Button", "yp w" . ButtonWidth, "复制")
copyCompressedAreaButton.OnEvent("Click", CopyCompressedNikkeArea)
; --- 行 10: 状态信息 (调整位置) ---
gStatusText := MyGui.Add("Text", "xm y+10 w300 vStatusMessage", "按 Ctrl+Alt+Q 获取信息, Ctrl+Alt+W 选取区域")
; --- 绑定其他 GUI 事件 ---
radio4k.OnEvent("Click", ResolutionChange)
radio2k.OnEvent("Click", ResolutionChange)
radio1080p.OnEvent("Click", ResolutionChange)
MyGui.OnEvent("Close", GuiClose)
; --- 显示 GUI ---
MyGui.Show("w" . MyGuiWidth)
; ==============================================================================
; --- 函数定义 ---
; ==============================================================================
; --- 自定义 SetCursor 函数 ---
SetCursor(cursorType := "") {
    static OCR_NORMAL := 32512, OCR_CROSS := 32515
    hCursor := DllCall("LoadCursorW", "Ptr", 0, "Ptr", (cursorType == "Cross" ? OCR_CROSS : OCR_NORMAL), "Ptr")
    DllCall("SetCursor", "Ptr", hCursor)
}
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
            ; 当分辨率变化时，也尝试重新计算压缩区域，因为它依赖于此
            CalculateNikkeCompressedArea()
        }
    }
}
; --- 热键定义: Ctrl+Alt+W ---
^!W:: {
    EnterScreenshotMode()
    ; 截图后自动触发计算
    CalculateNikkeCompressedArea()
}
; --- 核心换算逻辑 ---
; 将屏幕坐标转换为相对于目标窗口的换算坐标
ConvertScreenToCalculated(screenX, screenY) {
    global gTargethWnd, gSelectedRefWidth, gSelectedRefHeight, gStatusText
    if (!gTargethWnd or !WinExist("ahk_id " . gTargethWnd)) {
        gStatusText.Value := "转换错误: 目标窗口句柄无效。"
        return false
    }
    try {
        WinGetClientPos(&winX, &winY, &winW, &winH, gTargethWnd)
        if (winW <= 0 or winH <= 0) {
            throw Error("无效窗口尺寸")
        }
    } catch {
        gStatusText.Value := "转换错误: 无法获取客户区。"
        return false
    }
    ; 计算相对坐标
    relX := screenX - winX
    relY := screenY - winY
    ; 计算比例坐标
    propX := relX / winW
    propY := relY / winH
    ; 计算最终换算坐标
    finalX := Round(propX * gSelectedRefWidth)
    finalY := Round(propY * gSelectedRefHeight)
    return [finalX, finalY]
}
; --- 截图模式函数 (已优化) ---
EnterScreenshotMode() {
    global gCalculatedAreaEdit, borderGuis, gTargethWnd, gStatusText, gFocusedProgramEdit
    global gMouseCoordsEdit, gRelativeMouseCoordsEdit, gClientAreaEdit, gPixelColorEdit, gPixelCharacterBlock
    global gSelectedRefWidth, gSelectedRefHeight, gSelectionRatioEdit
    global gActualNikkeX, gActualNikkeY, gActualNikkeW, gActualNikkeH ; 使用全局变量存储实际值
    local hWnd, progName, winTitle, displayProgInfo
    local mX, mY, winX, winY, winW, winH, relX, relY, propX, propY, finalX, finalY, isInside := False
    local pixelColorRGB, strColor := "", sixDigitColor
    ; --- 检查或设置目标窗口句柄 ---
    if (!gTargethWnd or !WinExist("ahk_id " . gTargethWnd)) {
        ; 如果 gTargethWnd 无效，则尝试获取当前活动窗口作为目标
        hWnd := WinActive("A")
        if (!hWnd) {
            gStatusText.Value := "错误: 未找到活动窗口，无法进入截图模式。"
            gFocusedProgramEdit.Value := "N/A"
            return
        }
        gTargethWnd := hWnd ; 设置当前活动窗口为目标窗口
        ; 更新 GUI 显示聚焦窗口信息
        progName := WinGetProcessName("A")
        winTitle := WinGetTitle("A")
        displayProgInfo := progName ? progName : (winTitle ? winTitle : "N/A")
        gFocusedProgramEdit.Value := displayProgInfo
        gStatusText.Value := "已将当前窗口设置为目标窗口，进入截图模式。"
    }
    ; --- 获取并更新鼠标相关信息 (与 Ctrl+Alt+Q 类似) ---
    CoordMode "Mouse", "Screen"
    CoordMode "Pixel", "Screen"
    ; 清空旧的坐标信息 (如果需要)
    gCalculatedCoordsEdit.Value := ""
    gRelativeMouseCoordsEdit.Value := ""
    gMouseCoordsEdit.Value := ""
    gClientAreaEdit.Value := ""
    gPixelColorEdit.Value := ""
    gSelectionRatioEdit.Value := "" ; 清空选区相对比例
    gPixelCharacterBlock.Opt("c808080") ; 重置颜色块
    MouseGetPos(&mX, &mY)
    gMouseCoordsEdit.Value := mX . ", " . mY
    ; 获取像素颜色
    try {
        pixelColorRGB := PixelGetColor(mX, mY, "RGB")
        sixDigitColor := Format("{:06X}", pixelColorRGB)
        gPixelCharacterBlock.Opt("c" . sixDigitColor)
        strColor := "0x" . sixDigitColor
        gPixelColorEdit.Value := strColor
    } catch Error as e {
        gPixelColorEdit.Value := "获取失败: " . e.Message
        gPixelCharacterBlock.Opt("c808080")
    }
    ; 获取客户区和相对坐标
    try {
        WinGetClientPos(&winX, &winY, &winW, &winH, gTargethWnd)
        if (winW <= 0 or winH <= 0) {
            throw Error("无效窗口尺寸")
        }
        gClientAreaEdit.Value := winX . ", " . winY . ", " . winW . ", " . winH
    } catch Error as e {
        gStatusText.Value := "错误: 获取客户区失败 - " . e.Message
        gClientAreaEdit.Value := "Error"
        ; 继续执行，因为即使获取客户区失败，截图模式本身仍可能有用
    }
    isInside := (mX >= winX and mX < (winX + winW) and mY >= winY and mY < (winH + winH))
    if (isInside) {
        relX := mX - winX
        relY := mY - winY
        gRelativeMouseCoordsEdit.Value := relX . ", " . relY
        ; 仅当参考分辨率有效时才计算换算坐标
        if (gSelectedRefWidth > 0 and gSelectedRefHeight > 0) {
            propX := relX / winW
            propY := relY / winH
            finalX := Round(propX * gSelectedRefWidth)
            finalY := Round(propY * gSelectedRefHeight)
            gCalculatedCoordsEdit.Value := finalX . ", " . finalY
        } else {
            gCalculatedCoordsEdit.Value := "参考分辨率无效"
        }
    } else {
        gRelativeMouseCoordsEdit.Value := "N/A"
        gCalculatedCoordsEdit.Value := ""
    }
    ; --- 创建全屏覆盖的半透明 GUI ---
    screenshotOverlay := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    screenshotOverlay.BackColor := "000000" ; 黑色
    screenshotOverlay.Show("NoActivate w" . A_ScreenWidth . " h" . A_ScreenHeight . " x0 y0")
    WinSetTransparent(128, "ahk_id " . screenshotOverlay.Hwnd)
    SetCursor("Cross") ; 设置鼠标光标为十字形
    borderGuis := [] ; 清空边框GUI列表
    loop 4 {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
        g.BackColor := "Red"
        borderGuis.Push(g)
    }
    ; 等待鼠标左键按下
    while !GetKeyState("LButton", "P") {
        Sleep 20
        if GetKeyState("Esc", "P") {
            loop 4 {
                borderGuis[A_Index].Destroy()
            }
            borderGuis := [], SetCursor(), ToolTip()
            screenshotOverlay.Destroy()
            return
        }
    }
    CoordMode "Mouse", "Screen"
    MouseGetPos &x1, &y1 ; 获取鼠标按下时的起始坐标
    ; 鼠标左键按住时，实时更新选择框
    while GetKeyState("LButton", "P") {
        MouseGetPos &x2, &y2 ; 获取当前鼠标坐标
        x := Min(x1, x2)
        y := Min(y1, y2)
        w := Abs(x2 - x1)
        h := Abs(y2 - y1)
        ToolTip("x:" . x . " y:" . y . " w:" . w . " h:" . h, x, y - 20)
        d := 2 ; 边框宽度
        borderGuis[1].Show("NA x" . (x - d) . " y" . (y - d) . " w" . (w + 2 * d) . " h" . d) ; 顶部边框
        borderGuis[2].Show("NA x" . (x + w) . " y" . (y - d) . " w" . d . " h" . (h + 2 * d)) ; 右侧边框
        borderGuis[3].Show("NA x" . (x - d) . " y" . (y + h) . " w" . (w + 2 * d) . " h" . d) ; 底部边框
        borderGuis[4].Show("NA x" . (x - d) . " y" . (y - d) . " w" . d . " h" . (h + 2 * d)) ; 左侧边框
        Sleep 20
    }
    ToolTip() ; 隐藏提示信息
    MouseGetPos &x2, &y2 ; 获取鼠标释放时的最终坐标
    ; 销毁所有边框GUI
    loop 4 {
        if IsObject(borderGuis[A_Index]) {
            borderGuis[A_Index].Destroy()
        }
    }
    borderGuis := [], SetCursor()
    screenshotOverlay.Destroy()
    final_x1 := Min(x1, x2)
    final_y1 := Min(y1, y2)
    final_x2 := Max(x1, x2)
    final_y2 := Max(y1, y2)
    selectedW := Abs(final_x2 - final_x1)
    selectedH := Abs(final_y2 - final_y1)
    ; === 更新 gActualNikkeX, gActualNikkeY, gActualNikkeW, gActualNikkeH ===
    gActualNikkeX := final_x1
    gActualNikkeY := final_y1
    gActualNikkeW := selectedW
    gActualNikkeH := selectedH
    ; --- 执行坐标换算 ---
    if (!WinExist("ahk_id " . gTargethWnd)) {
        gStatusText.Value := "错误: 目标窗口已关闭或失效。"
        gCalculatedAreaEdit.Value := "无目标窗口，无法换算"
        gSelectionRatioEdit.Value := "N/A"
        return
    }
    local tempWinX, tempWinY, tempWinW, tempWinH
    try {
        WinGetClientPos(&tempWinX, &tempWinY, &tempWinW, &tempWinH, gTargethWnd)
        if (tempWinW <= 0 or tempWinH <= 0) {
            throw Error("无效目标窗口客户区尺寸")
        }
        gClientAreaEdit.Value := tempWinX . ", " . tempWinY . ", " . tempWinW . ", " . tempWinH
    } catch Error as e {
        gStatusText.Value := "错误: 获取目标窗口客户区失败 (用于计算比例) - " . e.Message
        gCalculatedAreaEdit.Value := "客户区获取失败"
        gSelectionRatioEdit.Value := "N/A"
        return
    }
    local relativeSelX1 := final_x1 - tempWinX
    local relativeSelY1 := final_y1 - tempWinY
    local relativeSelW := selectedW
    local relativeSelH := selectedH
    if (tempWinW > 0 and tempWinH > 0) {
        local propSelX1 := relativeSelX1 / tempWinW
        local propSelY1 := relativeSelY1 / tempWinH
        local propSelW := relativeSelW / tempWinW
        local propSelH := relativeSelH / tempWinH
        gSelectionRatioEdit.Value := Format("{:.3f}", propSelX1) . ", " . Format("{:.3f}", propSelY1) . ", " . Format("{:.3f}", propSelW) . ", " . Format("{:.3f}", propSelH)
    } else {
        gSelectionRatioEdit.Value := "客户区无效"
    }
    calc_p1 := ConvertScreenToCalculated(final_x1, final_y1)
    calc_p2 := ConvertScreenToCalculated(final_x2, final_y2)
    if (calc_p1 and calc_p2) {
        gCalculatedAreaEdit.Value := calc_p1[1] . ", " . calc_p1[2] . ", " . calc_p2[1] . ", " . calc_p2[2]
        gStatusText.Value := "区域坐标已换算并填入。"
    } else {
        gCalculatedAreaEdit.Value := "换算失败"
    }
}
; --- 热键定义: Ctrl+Alt+Q ---
^!Q:: {
    global MyGui, gFocusedProgramEdit, gCalculatedCoordsEdit, gStatusText, gSelectedRefWidth, gSelectedRefHeight, gMouseCoordsEdit, gRelativeMouseCoordsEdit, gClientAreaEdit, gTargethWnd, gPixelColorEdit, gPixelCharacterBlock
    global gSelectionRatioEdit
    global gActualNikkeX, gActualNikkeY, gActualNikkeW, gActualNikkeH ; 使用全局变量存储实际值
    local hWnd, progName, winTitle, displayProgInfo := "", mX, mY, winX, winY, winW, winH, relX, relY, propX, propY, finalX, finalY, isInside := False
    local pixelColorRGB, strColor := "", sixDigitColor
    if !IsObject(gPixelCharacterBlock) {
        MsgBox("脚本错误: 'gPixelCharacterBlock' 未初始化。", "初始化错误", "IconError")
        return
    }
    CoordMode "Mouse", "Screen"
    CoordMode "Pixel", "Screen"
    gCalculatedCoordsEdit.Value := ""
    gRelativeMouseCoordsEdit.Value := ""
    gMouseCoordsEdit.Value := ""
    gClientAreaEdit.Value := ""
    gPixelColorEdit.Value := ""
    gSelectionRatioEdit.Value := ""
    gStatusText.Value := "正在处理..."
    gPixelCharacterBlock.Opt("c808080")
    hWnd := WinActive("A")
    if (!hWnd) {
        gStatusText.Value := "错误: 未找到活动窗口。"
        gFocusedProgramEdit.Value := "N/A"
        gTargethWnd := ""
        return
    }
    gTargethWnd := hWnd
    progName := WinGetProcessName("A")
    winTitle := WinGetTitle("A")
    displayProgInfo := progName ? progName : (winTitle ? winTitle : "N/A")
    gFocusedProgramEdit.Value := displayProgInfo
    MouseGetPos(&mX, &mY)
    gMouseCoordsEdit.Value := mX . ", " . mY
    ; === 更新 gActualNikkeX, gActualNikkeY (W和H此时设为1，表示只取点) ===
    gActualNikkeX := mX
    gActualNikkeY := mY
    gActualNikkeW := 1 ; 默认为1，表示一个点
    gActualNikkeH := 1 ; 默认为1，表示一个点
    try {
        pixelColorRGB := PixelGetColor(mX, mY, "RGB")
        sixDigitColor := Format("{:06X}", pixelColorRGB)
        gPixelCharacterBlock.Opt("c" . sixDigitColor)
        strColor := "0x" . sixDigitColor
        gPixelColorEdit.Value := strColor
    } catch Error as e {
        gPixelColorEdit.Value := "获取失败: " . e.Message
        gPixelCharacterBlock.Opt("c808080")
    }
    try {
        WinGetClientPos(&winX, &winY, &winW, &winH, hWnd)
        if (winW <= 0 or winH <= 0) {
            throw Error("无效窗口尺寸")
        }
        gClientAreaEdit.Value := winX . ", " . winY . ", " . winW . ", " . winH
    } catch Error as e {
        gStatusText.Value := "错误: 获取客户区失败 - " . e.Message
        gClientAreaEdit.Value := "Error"
        return
    }
    isInside := (mX >= winX and mX < (winX + winW) and mY >= winY and mY < (winY + winH))
    if (isInside) {
        relX := mX - winX
        relY := mY - winY
        gRelativeMouseCoordsEdit.Value := relX . ", " . relY
        if (gSelectedRefWidth > 0 and gSelectedRefHeight > 0) {
            propX := relX / winW
            propY := relY / winH
            finalX := Round(propX * gSelectedRefWidth)
            finalY := Round(propY * gSelectedRefHeight)
            gCalculatedCoordsEdit.Value := finalX . ", " . finalY
        } else {
            gCalculatedCoordsEdit.Value := "参考分辨率无效"
        }
        gStatusText.Value := "边界检查: 内部"
    } else {
        gRelativeMouseCoordsEdit.Value := "N/A"
        gCalculatedCoordsEdit.Value := ""
        gStatusText.Value := "边界检查: 外部 (请重新聚焦鼠标)"
    }
    ; 触发自动计算压缩区域
    CalculateNikkeCompressedArea()
}
; --- 跳转按钮点击处理函数 ---
JumpToCoords(GuiCtrlObj, Info) {
    global MyGui, gCalculatedCoordsEdit, gStatusText, gSelectedRefWidth, gSelectedRefHeight, gTargethWnd
    local targetX, targetY, propX, propY, desiredRelX, desiredRelY, finalScreenX, finalScreenY, hWnd, winX, winY, winW, winH, inputText, match
    gStatusText.Value := "正在处理跳转..."
    if (!gTargethWnd or !WinExist("ahk_id " . gTargethWnd)) {
        gStatusText.Value := "错误: 请先用 Ctrl+Alt+Q 记录一个有效的目标窗口。"
        gTargethWnd := ""
        return
    }
    hWnd := gTargethWnd
    inputText := gCalculatedCoordsEdit.Value
    if (!RegExMatch(inputText, "^\s*(-?\d+)\s*[,; ]\s*(-?\d+)\s*$", &match)) {
        gStatusText.Value := "错误: 无效坐标格式 (请输入 X, Y)"
        return
    }
    targetX := Integer(match[1]), targetY := Integer(match[2])
    if (targetX < 0 or targetX >= gSelectedRefWidth or targetY < 0 or targetY >= gSelectedRefHeight) {
        gStatusText.Value := "提示: 输入坐标可能超出目标分辨率范围。"
    }
    try {
        WinGetClientPos(&winX, &winY, &winW, &winH, hWnd)
        if (winW <= 0 or winH <= 0) {
            throw Error("无效窗口尺寸")
        }
    } catch Error as e {
        gStatusText.Value := "错误: 获取目标窗口客户区失败 - " . e.Message
        return
    }
    if (gSelectedRefWidth <= 0 or gSelectedRefHeight <= 0) {
        gStatusText.Value := "错误: 无效的目标分辨率尺寸用于计算。"
        return
    }
    propX := targetX / gSelectedRefWidth
    propY := targetY / gSelectedRefHeight
    desiredRelX := propX * winW
    desiredRelY := propY * winH
    finalScreenX := Round(winX + desiredRelX)
    finalScreenY := Round(winY + desiredRelY)
    try {
        WinActivate("ahk_id " . hWnd)
        Sleep 100
    } catch Error as e {
        gStatusText.Value := "警告: 激活目标窗口失败 - " . e.Message . "，仍尝试跳转。"
    }
    CoordMode "Mouse", "Screen"
    MouseMove finalScreenX, finalScreenY, 0
    gStatusText.Value := "鼠标已跳转至目标窗口对应坐标: " . finalScreenX . ", " . finalScreenY
}
; --- 检查区域按钮点击处理函数 ---
CheckCalculatedArea(GuiCtrlObj, Info) {
    global MyGui, gCalculatedAreaEdit, gStatusText, gSelectedRefWidth, gSelectedRefHeight, gTargethWnd
    local inputText, match, calc_x1, calc_y1, calc_x2, calc_y2
    local winX, winY, winW, winH, screen_x1, screen_y1, screen_x2, screen_y2
    local borderGuisLocal := [] ; 用于局部范围的边框GUI
    gStatusText.Value := "正在检查区域..."
    ; 1. 检查目标窗口句柄
    if (!gTargethWnd or !WinExist("ahk_id " . gTargethWnd)) {
        gStatusText.Value := "错误: 请先用 Ctrl+Alt+Q 记录一个有效的目标窗口。"
        gTargethWnd := ""
        return
    }
    ; 2. 获取并解析换算区域输入
    inputText := gCalculatedAreaEdit.Value
    if (!RegExMatch(inputText, "^\s*(-?\d+)\s*[,; ]\s*(-?\d+)\s*[,; ]\s*(-?\d+)\s*[,; ]\s*(-?\d+)\s*$", &match)) {
        gStatusText.Value := "错误: 无效区域格式 (请输入 X1, Y1, X2, Y2)"
        return
    }
    calc_x1 := Integer(match[1])
    calc_y1 := Integer(match[2])
    calc_x2 := Integer(match[3])
    calc_y2 := Integer(match[4])
    ; 3. 获取目标窗口的客户区尺寸
    try {
        WinGetClientPos(&winX, &winY, &winW, &winH, gTargethWnd)
        if (winW <= 0 or winH <= 0) {
            throw Error("无效窗口尺寸")
        }
    } catch Error as e {
        gStatusText.Value := "错误: 获取目标窗口客户区失败 - " . e.Message
        return
    }
    ; 4. 检查参考分辨率的有效性
    if (gSelectedRefWidth <= 0 or gSelectedRefHeight <= 0) {
        gStatusText.Value := "错误: 无效的目标分辨率尺寸用于计算。"
        return
    }
    ; 5. 将换算坐标转换回屏幕坐标
    propX1 := calc_x1 / gSelectedRefWidth
    propY1 := calc_y1 / gSelectedRefHeight
    desiredRelX1 := propX1 * winW
    desiredRelY1 := propY1 * winH
    screen_x1 := Round(winX + desiredRelX1)
    screen_y1 := Round(winY + desiredRelY1)
    propX2 := calc_x2 / gSelectedRefWidth
    propY2 := calc_y2 / gSelectedRefHeight
    desiredRelX2 := propX2 * winW
    desiredRelY2 := propY2 * winH
    screen_x2 := Round(winX + desiredRelX2)
    screen_y2 := Round(winY + desiredRelY2)
    ; 6. 绘制闪烁红框
    local borderThickness := 2
    local flashCount := 5
    local flashDelay := 200
    local displayX := Min(screen_x1, screen_x2)
    local displayY := Min(screen_y1, screen_y2)
    local rectW := Abs(screen_x2 - screen_x1)
    local rectH := Abs(screen_y2 - screen_y1)
    loop 4 {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
        g.BackColor := "Red"
        borderGuisLocal.Push(g)
    }
    loop flashCount * 2 {
        if (Mod(A_Index, 2) != 0) {
            borderGuisLocal[1].Show("NA x" . (displayX - borderThickness) . " y" . (displayY - borderThickness) . " w" . (rectW + 2 * borderThickness) . " h" . borderThickness)
            borderGuisLocal[2].Show("NA x" . (displayX + rectW) . " y" . (displayY - borderThickness) . " w" . borderThickness . " h" . (rectH + 2 * borderThickness))
            borderGuisLocal[3].Show("NA x" . (displayX - borderThickness) . " y" . (displayY + rectH) . " w" . (rectW + 2 * borderThickness) . " h" . borderThickness)
            borderGuisLocal[4].Show("NA x" . (displayX - borderThickness) . " y" . (displayY - borderThickness) . " w" . borderThickness . " h" . (rectH + 2 * borderThickness))
        } else {
            loop 4 {
                borderGuisLocal[A_Index].Hide()
            }
        }
        Sleep flashDelay
    }
    loop 4 {
        if IsObject(borderGuisLocal[A_Index]) {
            borderGuisLocal[A_Index].Destroy()
        }
    }
    gStatusText.Value := "区域检查完成: " . screen_x1 . "," . screen_y1 . "," . screen_x2 . "," . screen_y2
}
; === 事件处理函数: 当 gCalculatedAreaEdit 值变化时自动触发计算 ===
CalculatedAreaChanged(GuiCtrlObj, Info) {
    ; 简单延迟一下，避免快速输入时频繁触发
    SetTimer(CalculateNikkeCompressedArea, -100) ; 延迟100ms后执行一次
}
; --- 计算识图压缩区域函数 ---
; 此函数现在由 CalculatedAreaChanged 或 ResolutionChange 或热键触发
CalculateNikkeCompressedArea() {
    global gActualNikkeX, gActualNikkeY, gActualNikkeW, gActualNikkeH ; 使用存储的实际数值 (屏幕绝对坐标)
    global gCompressedNikkeAreaEdit, gStatusText
    global gTargethWnd, gSelectedRefWidth, gSelectedRefHeight
    global gSelectionRatioEdit ; 用于获取 t1, t2, t3, t4
    local winX, winY, winW, winH
    ; 初始化局部变量，避免警告
    local t1, t2, t3, t4
    ; 1. 检查目标窗口句柄
    if (!gTargethWnd or !WinExist("ahk_id " . gTargethWnd)) {
        gStatusText.Value := "计算错误: 无效目标窗口或区域。"
        gTargethWnd := ""
        gCompressedNikkeAreaEdit.Value := "无目标窗口/区域"
        return
    }
    ; 检查是否已经通过 Ctrl+Alt+Q 或 Ctrl+Alt+W 捕获了 Nikke 区域的实际值
    if (gActualNikkeX == 0 && gActualNikkeY == 0 && gActualNikkeW == 0 && gActualNikkeH == 0) {
        gStatusText.Value := "计算错误: 请先使用 Ctrl+Alt+W 选取区域，或使用 Ctrl+Alt+Q 记录一个点。"
        gCompressedNikkeAreaEdit.Value := "请选取区域"
        return
    }
    ; 如果原始宽度或高度为0，提示警告，但仍尝试计算。
    if (gActualNikkeW == 0 || gActualNikkeH == 0) {
        gStatusText.Value := "警告: 原始宽度或高度为零。公式可能不准确。"
    }
    ; 2. 获取目标窗口的客户区尺寸
    try {
        WinGetClientPos(&winX, &winY, &winW, &winH, gTargethWnd)
        if (winW <= 0 or winH <= 0) {
            throw Error("无效窗口尺寸")
        }
    } catch Error as e {
        gStatusText.Value := "计算错误: 获取目标窗口客户区失败 - " . e.Message
        gCompressedNikkeAreaEdit.Value := "客户区获取失败"
        return
    }
    ; 3. 获取选区相对比例 t1, t2, t3, t4
    local ratioText := gSelectionRatioEdit.Value
    if (!RegExMatch(ratioText, "^\s*([\d\.-]+)\s*,\s*([\d\.-]+)\s*,\s*([\d\.-]+)\s*,\s*([\d\.-]+)\s*$", &match)) {
        gStatusText.Value := "计算错误: 选区相对比例格式不正确，请先选取区域或记录点。"
        gCompressedNikkeAreaEdit.Value := "相对比例无效"
        return
    }
    ; 将捕获到的字符串转换为浮点数，并格式化为3位小数，用于输出字符串。
    t1 := Format("{:.3f}", match[1] + 0.0)
    t2 := Format("{:.3f}", match[2] + 0.0)
    t3 := Format("{:.3f}", match[3] + 0.0)
    t4 := Format("{:.3f}", match[4] + 0.0)
    ; 4. 格式化输出字符串，直接使用提供的公式
    local outputStr := ""
    local quote := Chr(34) ; 获取双引号字符
    ; 压缩后的 X1 坐标：NikkeX + t1 * NikkeW
    outputStr .= "NikkeX + " . t1 . " * NikkeW . " . quote . " " . quote
    outputStr .= ", "
    ; 压缩后的 Y1 坐标：NikkeY + t2 * NikkeH
    outputStr .= "NikkeY + " . t2 . " * NikkeH . " . quote . " " . quote
    outputStr .= ", "
    ; 压缩后的 X2 坐标：NikkeX + t1 * NikkeW + t3 * NikkeW
    outputStr .= "NikkeX + " . t1 . " * NikkeW + " . t3 . " * NikkeW . " . quote . " " . quote
    outputStr .= ", "
    ; 压缩后的 Y2 坐标：NikkeY + t2 * NikkeH + t4 * NikkeH
    outputStr .= "NikkeY + " . t2 . " * NikkeH + " . t4 . " * NikkeH . " . quote . " " . quote
    gCompressedNikkeAreaEdit.Value := outputStr
    gStatusText.Value := "识图区域公式已生成。"
}
; --- 复制压缩后识图区域按钮事件处理函数 ---
CopyCompressedNikkeArea(GuiCtrlObj, Info) {
    global gCompressedNikkeAreaEdit, gStatusText
    compressedValue := gCompressedNikkeAreaEdit.Value
    if (compressedValue and compressedValue != "无目标窗口/区域" and compressedValue != "请选取区域" and compressedValue != "客户区获取失败" and compressedValue != "目标分辨率无效" and compressedValue != "格式错误" and compressedValue != "请设置数值") {
        A_Clipboard := compressedValue
        gStatusText.Value := "压缩后识图区域 '" . compressedValue . "' 已复制!"
    } else {
        gStatusText.Value := "没有有效压缩区域可复制。"
    }
    SetTimer(() => gStatusText.Value := "", -2000)
}
; --- GUI 关闭处理函数 ---
GuiClose(GuiObj) {
    ExitApp()
}
; --- 复制按钮事件处理函数 ---
CopyPixelColor(GuiCtrlObj, Info) {
    global gPixelColorEdit, gStatusText
    colorValue := gPixelColorEdit.Value
    if (colorValue and colorValue != "获取失败") {
        A_Clipboard := colorValue
        gStatusText.Value := "颜色值 '" . colorValue . "' 已复制!"
    } else {
        gStatusText.Value := "没有有效颜色值可复制。"
    }
    SetTimer(() => gStatusText.Value := "", -2000)
}
CopyCalculatedCoords(GuiCtrlObj, Info) {
    global gCalculatedCoordsEdit, gStatusText
    coordsValue := gCalculatedCoordsEdit.Value
    if (coordsValue) {
        A_Clipboard := coordsValue
        gStatusText.Value := "换算坐标 '" . coordsValue . "' 已复制!"
    } else {
        gStatusText.Value := "没有换算坐标可复制。"
    }
    SetTimer(() => gStatusText.Value := "", -2000)
}
