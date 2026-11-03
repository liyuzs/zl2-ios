// ZL2-iOS · 完整主题色板（自动生成，对齐 ZL2 的 Color.kt + Theme.kt）
// 来源：ui/theme/Color.kt（35 角色 × 7 主题 × 亮暗 = 490 色值）
import SwiftUI

/// 主题标识（对齐 ColorThemeType）
enum ZLThemeType: String, CaseIterable, Identifiable {
    case dynamic = "动态"
    case embermire = "釉烬"
    case velvetRose = "绒玫"
    case mistwave = "雾澜"
    case glacier = "冰川"
    case verdantField = "原野暮光"
    case urbanAsh = "钛影"
    case verdantDawn = "静林之晨"
    case custom = "自定义"
    var id: String { rawValue }
}

/// 一套完整色板（35 个 Material3 颜色角色）
struct ZLPaletteV2 {
    var primary: Color
    var onPrimary: Color
    var primaryContainer: Color
    var onPrimaryContainer: Color
    var secondary: Color
    var onSecondary: Color
    var secondaryContainer: Color
    var onSecondaryContainer: Color
    var tertiary: Color
    var onTertiary: Color
    var tertiaryContainer: Color
    var onTertiaryContainer: Color
    var error: Color
    var onError: Color
    var errorContainer: Color
    var onErrorContainer: Color
    var background: Color
    var onBackground: Color
    var surface: Color
    var onSurface: Color
    var surfaceVariant: Color
    var onSurfaceVariant: Color
    var outline: Color
    var outlineVariant: Color
    var scrim: Color
    var inverseSurface: Color
    var inverseOnSurface: Color
    var inversePrimary: Color
    var surfaceDim: Color
    var surfaceBright: Color
    var surfaceContainerLowest: Color
    var surfaceContainerLow: Color
    var surfaceContainer: Color
    var surfaceContainerHigh: Color
    var surfaceContainerHighest: Color

    /// 按索引取色（7 主题顺序）
    func color(for index: Int) -> Color {
        let all: [Color] = [primary, onPrimary, primaryContainer, onPrimaryContainer, secondary, onSecondary, secondaryContainer, onSecondaryContainer, tertiary, onTertiary, tertiaryContainer, onTertiaryContainer, error, onError, errorContainer, onErrorContainer, background, onBackground, surface, onSurface, surfaceVariant, onSurfaceVariant, outline, outlineVariant, scrim, inverseSurface, inverseOnSurface, inversePrimary, surfaceDim, surfaceBright, surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest]
        return all[min(max(index, 0), all.count - 1)]
    }
}

// MARK: - 亮色模式色值
enum ZLPaletteLight {
    static let primary: [UInt32] = [0xFFA63A17, 0xFF723D57, 0xFF426469, 0xFF006684, 0xFF676014, 0xFF5E5E5F, 0xFF004814]
    static let onPrimary: [UInt32] = [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]
    static let primaryContainer: [UInt32] = [0xFFFE7A52, 0xFF9B607C, 0xFFB1D5DB, 0xFF4CAFD6, 0xFFEFE58B, 0xFFAEAEAE, 0xFF276E31]
    static let onPrimaryContainer: [UInt32] = [0xFF2F0700, 0xFFFFFFFF, 0xFF1E4146, 0xFF001B26, 0xFF1F1C00, 0xFF222324, 0xFFFFFFFF]
    static let secondary: [UInt32] = [0xFF894F3D, 0xFF725762, 0xFF546163, 0xFF426372, 0xFF635F41, 0xFF5F5E5E, 0xFF4A6548]
    static let onSecondary: [UInt32] = [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]
    static let secondaryContainer: [UInt32] = [0xFFFFBBA7, 0xFFFFDAE8, 0xFFD8E6E9, 0xFFCAECFE, 0xFFEAE3BE, 0xFFE8E6E5, 0xFFCFEFCA]
    static let onSecondaryContainer: [UInt32] = [0xFF5C2B1C, 0xFF5B414D, 0xFF3E4B4D, 0xFF2E4F5D, 0xFF1E1C05, 0xFF4A4A4A, 0xFF365135]
    static let tertiary: [UInt32] = [0xFF6E5E00, 0xFF773F27, 0xFF655975, 0xFF794C91, 0xFF406653, 0xFF615D5F, 0xFF003C77]
    static let onTertiary: [UInt32] = [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]
    static let tertiaryContainer: [UInt32] = [0xFFBAA015, 0xFFA26247, 0xFFD8C9E9, 0xFFC390DB, 0xFFC1ECD4, 0xFFB2ADAF, 0xFF2960A6]
    static let onTertiaryContainer: [UInt32] = [0xFF1A1500, 0xFFFFFFFF, 0xFF423751, 0xFF2B0041, 0xFF002114, 0xFF252324, 0xFFFFFFFF]
    static let error: [UInt32] = [0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A]
    static let onError: [UInt32] = [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]
    static let errorContainer: [UInt32] = [0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6]
    static let onErrorContainer: [UInt32] = [0xFF410002, 0xFF410002, 0xFF410002, 0xFF410002, 0xFF410002, 0xFF410002, 0xFF410002]
    static let background: [UInt32] = [0xFFFFF8F6, 0xFFFFF8F8, 0xFFFAF9F9, 0xFFF6FAFD, 0xFFFEF9EB, 0xFFFCF8F8, 0xFFF7FBF2]
    static let onBackground: [UInt32] = [0xFF241916, 0xFF1F1A1C, 0xFF1A1C1C, 0xFF181C1F, 0xFF1D1C14, 0xFF1C1B1B, 0xFF181D18]
    static let surface: [UInt32] = [0xFFFFF8F6, 0xFFFFF8F8, 0xFFFAF9F9, 0xFFF6FAFD, 0xFFFEF9EB, 0xFFFCF8F8, 0xFFF7FBF2]
    static let onSurface: [UInt32] = [0xFF241916, 0xFF1F1A1C, 0xFF1A1C1C, 0xFF181C1F, 0xFF1D1C14, 0xFF1C1B1B, 0xFF181D18]
    static let surfaceVariant: [UInt32] = [0xFFFCDBD3, 0xFFF1DEE4, 0xFFDDE4E5, 0xFFDAE4EA, 0xFFE7E3D0, 0xFFE0E3E3, 0xFFDCE5D7]
    static let onSurfaceVariant: [UInt32] = [0xFF58423B, 0xFF504348, 0xFF414849, 0xFF3E484E, 0xFF49473A, 0xFF444748, 0xFF40493E]
    static let outline: [UInt32] = [0xFF8B716A, 0xFF827378, 0xFF71787A, 0xFF6E797E, 0xFF7A7768, 0xFF747878, 0xFF707A6D]
    static let outlineVariant: [UInt32] = [0xFFDFC0B7, 0xFFD4C2C8, 0xFFC1C8C9, 0xFFBEC8CE, 0xFFCBC7B5, 0xFFC4C7C7, 0xFFC0C9BB]
    static let scrim: [UInt32] = [0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000]
    static let inverseSurface: [UInt32] = [0xFF3B2D2A, 0xFF352F31, 0xFF2F3131, 0xFF2D3134, 0xFF323128, 0xFF313030, 0xFF2D322C]
    static let inverseOnSurface: [UInt32] = [0xFFFFEDE8, 0xFFF9EEF0, 0xFFF1F1F0, 0xFFEEF1F4, 0xFFF5F0E3, 0xFFF4F0EF, 0xFFEEF2E9]
    static let inversePrimary: [UInt32] = [0xFFFFB59F, 0xFFF9B2D2, 0xFFA9CDD3, 0xFF73D2FB, 0xFFD2C972, 0xFFC7C6C6, 0xFF8ED88E]
    static let surfaceDim: [UInt32] = [0xFFEBD5D0, 0xFFE2D7DA, 0xFFDADADA, 0xFFD7DADE, 0xFFDEDACC, 0xFFDDD9D9, 0xFFD8DBD3]
    static let surfaceBright: [UInt32] = [0xFFFFF8F6, 0xFFFFF8F8, 0xFFFAF9F9, 0xFFF6FAFD, 0xFFFEF9EB, 0xFFFCF8F8, 0xFFF7FBF2]
    static let surfaceContainerLowest: [UInt32] = [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]
    static let surfaceContainerLow: [UInt32] = [0xFFFFF1ED, 0xFFFCF1F3, 0xFFF4F3F3, 0xFFF0F4F7, 0xFFF8F3E6, 0xFFF7F3F2, 0xFFF1F5EC]
    static let surfaceContainer: [UInt32] = [0xFFFFE9E4, 0xFFF7EBED, 0xFFEEEEEE, 0xFFEBEEF1, 0xFFF2EEE0, 0xFFF1EDEC, 0xFFECEFE6]
    static let surfaceContainerHigh: [UInt32] = [0xFFFAE3DD, 0xFFF1E5E8, 0xFFE8E8E8, 0xFFE5E9EC, 0xFFEDE8DA, 0xFFEBE7E7, 0xFFE6E9E1]
    static let surfaceContainerHighest: [UInt32] = [0xFFF4DED8, 0xFFEBE0E2, 0xFFE3E2E2, 0xFFDFE3E6, 0xFFE7E2D5, 0xFFE5E2E1, 0xFFE0E4DB]
}

// MARK: - 暗色模式色值
enum ZLPaletteDark {
    static let primary: [UInt32] = [0xFFFFB59F, 0xFFF9B2D2, 0xFFCEF3F9, 0xFF73D2FB, 0xFFD2C972, 0xFFC7C6C6, 0xFF8ED88E]
    static let onPrimary: [UInt32] = [0xFF5F1600, 0xFF4F2039, 0xFF11353A, 0xFF003546, 0xFF353100, 0xFF2F3131, 0xFF00390F]
    static let primaryContainer: [UInt32] = [0xFFC4502B, 0xFF915873, 0xFFA5C9CF, 0xFF007EA2, 0xFF4E4800, 0xFF9B9B9B, 0xFF005219]
    static let onPrimaryContainer: [UInt32] = [0xFFFFFFFF, 0xFFFFFFFF, 0xFF14383D, 0xFFFFFFFF, 0xFFEFE58B, 0xFF0B0C0D, 0xFFA6F2A5]
    static let secondary: [UInt32] = [0xFFFFB59F, 0xFFE0BDCB, 0xFFBBC9CB, 0xFFAACBDD, 0xFFCDC7A3, 0xFFC8C6C6, 0xFFB0CFAB]
    static let onSecondary: [UInt32] = [0xFF512214, 0xFF412A34, 0xFF263335, 0xFF113442, 0xFF343117, 0xFF303030, 0xFF1C361D]
    static let secondaryContainer: [UInt32] = [0xFF643122, 0xFF4F3641, 0xFF333F41, 0xFF204250, 0xFF4B482C, 0xFF3D3D3D, 0xFF294329]
    static let onSecondaryContainer: [UInt32] = [0xFFFFC8B9, 0xFFEBC7D5, 0xFFC5D3D6, 0xFFB4D6E8, 0xFFEAE3BE, 0xFFD3D0D0, 0xFFB9D9B5]
    static let tertiary: [UInt32] = [0xFFF0D44C, 0xFFFFB598, 0xFFF5E9FF, 0xFFE7B3FF, 0xFFA6D0B9, 0xFFCBC5C7, 0xFFA7C8FF]
    static let onTertiary: [UInt32] = [0xFF393000, 0xFF52220C, 0xFF362C45, 0xFF471C5F, 0xFF0F3727, 0xFF323031, 0xFF003061]
    static let tertiaryContainer: [UInt32] = [0xFFC4AA22, 0xFF97593F, 0xFFCCBDDD, 0xFFAF7EC7, 0xFF284E3C, 0xFFA09B9D, 0xFF004688]
    static let onTertiaryContainer: [UInt32] = [0xFF272000, 0xFFFFFFFF, 0xFF392F48, 0xFF000000, 0xFFC1ECD4, 0xFF0F0D0F, 0xFFD1E0FF]
    static let error: [UInt32] = [0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB]
    static let onError: [UInt32] = [0xFF690005, 0xFF690005, 0xFF690005, 0xFF690005, 0xFF690005, 0xFF690005, 0xFF690005]
    static let errorContainer: [UInt32] = [0xFF93000A, 0xFF93000A, 0xFF93000A, 0xFF93000A, 0xFF93000A, 0xFF93000A, 0xFF93000A]
    static let onErrorContainer: [UInt32] = [0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6]
    static let background: [UInt32] = [0xFF1C110E, 0xFF171214, 0xFF121414, 0xFF101416, 0xFF15140C, 0xFF141313, 0xFF101410]
    static let onBackground: [UInt32] = [0xFFF4DED8, 0xFFEBE0E2, 0xFFE3E2E2, 0xFFDFE3E6, 0xFFE7E2D5, 0xFFE5E2E1, 0xFFE0E4DB]
    static let surface: [UInt32] = [0xFF1C110E, 0xFF171214, 0xFF121414, 0xFF101416, 0xFF15140C, 0xFF141313, 0xFF101410]
    static let onSurface: [UInt32] = [0xFFF4DED8, 0xFFEBE0E2, 0xFFE3E2E2, 0xFFDFE3E6, 0xFFE7E2D5, 0xFFE5E2E1, 0xFFE0E4DB]
    static let surfaceVariant: [UInt32] = [0xFF58423B, 0xFF504348, 0xFF414849, 0xFF3E484E, 0xFF49473A, 0xFF444748, 0xFF40493E]
    static let onSurfaceVariant: [UInt32] = [0xFFDFC0B7, 0xFFD4C2C8, 0xFFC1C8C9, 0xFFBEC8CE, 0xFFCBC7B5, 0xFFC4C7C7, 0xFFC0C9BB]
    static let outline: [UInt32] = [0xFFA68B83, 0xFF9D8C92, 0xFF8B9293, 0xFF889298, 0xFF949181, 0xFF8E9192, 0xFF8A9386]
    static let outlineVariant: [UInt32] = [0xFF58423B, 0xFF504348, 0xFF414849, 0xFF3E484E, 0xFF49473A, 0xFF444748, 0xFF40493E]
    static let scrim: [UInt32] = [0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000]
    static let inverseSurface: [UInt32] = [0xFFF4DED8, 0xFFEBE0E2, 0xFFE3E2E2, 0xFFDFE3E6, 0xFFE7E2D5, 0xFFE5E2E1, 0xFFE0E4DB]
    static let inverseOnSurface: [UInt32] = [0xFF3B2D2A, 0xFF352F31, 0xFF2F3131, 0xFF2D3134, 0xFF323128, 0xFF313030, 0xFF2D322C]
    static let inversePrimary: [UInt32] = [0xFFA63A17, 0xFF854D68, 0xFF426469, 0xFF006684, 0xFF676014, 0xFF5E5E5F, 0xFF246C2F]
    static let surfaceDim: [UInt32] = [0xFF1C110E, 0xFF171214, 0xFF121414, 0xFF101416, 0xFF15140C, 0xFF141313, 0xFF101410]
    static let surfaceBright: [UInt32] = [0xFF443632, 0xFF3E373A, 0xFF38393A, 0xFF353A3C, 0xFF3B3930, 0xFF3A3939, 0xFF363A34]
    static let surfaceContainerLowest: [UInt32] = [0xFF160C09, 0xFF120D0F, 0xFF0D0E0F, 0xFF0A0F11, 0xFF0F0E07, 0xFF0E0E0E, 0xFF0B0F0B]
    static let surfaceContainerLow: [UInt32] = [0xFF241916, 0xFF1F1A1C, 0xFF1A1C1C, 0xFF181C1F, 0xFF1D1C14, 0xFF1C1B1B, 0xFF181D18]
    static let surfaceContainer: [UInt32] = [0xFF291D19, 0xFF241E20, 0xFF1E2020, 0xFF1C2023, 0xFF212017, 0xFF201F1F, 0xFF1C211B]
    static let surfaceContainerHigh: [UInt32] = [0xFF342723, 0xFF2E282A, 0xFF292A2A, 0xFF262B2D, 0xFF2C2A21, 0xFF2A2A2A, 0xFF272B26]
    static let surfaceContainerHighest: [UInt32] = [0xFF3F322E, 0xFF393335, 0xFF333535, 0xFF313538, 0xFF37352C, 0xFF353434, 0xFF323630]
}

// MARK: - 从色值构造色板
extension ZLPaletteV2 {
    static func light(index: Int) -> ZLPaletteV2 {
        let i = min(max(index, 0), 6)
        return ZLPaletteV2(
            primary: Color(hex: ZLPaletteLight.primary[i]),
            onPrimary: Color(hex: ZLPaletteLight.onPrimary[i]),
            primaryContainer: Color(hex: ZLPaletteLight.primaryContainer[i]),
            onPrimaryContainer: Color(hex: ZLPaletteLight.onPrimaryContainer[i]),
            secondary: Color(hex: ZLPaletteLight.secondary[i]),
            onSecondary: Color(hex: ZLPaletteLight.onSecondary[i]),
            secondaryContainer: Color(hex: ZLPaletteLight.secondaryContainer[i]),
            onSecondaryContainer: Color(hex: ZLPaletteLight.onSecondaryContainer[i]),
            tertiary: Color(hex: ZLPaletteLight.tertiary[i]),
            onTertiary: Color(hex: ZLPaletteLight.onTertiary[i]),
            tertiaryContainer: Color(hex: ZLPaletteLight.tertiaryContainer[i]),
            onTertiaryContainer: Color(hex: ZLPaletteLight.onTertiaryContainer[i]),
            error: Color(hex: ZLPaletteLight.error[i]),
            onError: Color(hex: ZLPaletteLight.onError[i]),
            errorContainer: Color(hex: ZLPaletteLight.errorContainer[i]),
            onErrorContainer: Color(hex: ZLPaletteLight.onErrorContainer[i]),
            background: Color(hex: ZLPaletteLight.background[i]),
            onBackground: Color(hex: ZLPaletteLight.onBackground[i]),
            surface: Color(hex: ZLPaletteLight.surface[i]),
            onSurface: Color(hex: ZLPaletteLight.onSurface[i]),
            surfaceVariant: Color(hex: ZLPaletteLight.surfaceVariant[i]),
            onSurfaceVariant: Color(hex: ZLPaletteLight.onSurfaceVariant[i]),
            outline: Color(hex: ZLPaletteLight.outline[i]),
            outlineVariant: Color(hex: ZLPaletteLight.outlineVariant[i]),
            scrim: Color(hex: ZLPaletteLight.scrim[i]),
            inverseSurface: Color(hex: ZLPaletteLight.inverseSurface[i]),
            inverseOnSurface: Color(hex: ZLPaletteLight.inverseOnSurface[i]),
            inversePrimary: Color(hex: ZLPaletteLight.inversePrimary[i]),
            surfaceDim: Color(hex: ZLPaletteLight.surfaceDim[i]),
            surfaceBright: Color(hex: ZLPaletteLight.surfaceBright[i]),
            surfaceContainerLowest: Color(hex: ZLPaletteLight.surfaceContainerLowest[i]),
            surfaceContainerLow: Color(hex: ZLPaletteLight.surfaceContainerLow[i]),
            surfaceContainer: Color(hex: ZLPaletteLight.surfaceContainer[i]),
            surfaceContainerHigh: Color(hex: ZLPaletteLight.surfaceContainerHigh[i]),
            surfaceContainerHighest: Color(hex: ZLPaletteLight.surfaceContainerHighest[i]),
        )
    }

    static func dark(index: Int) -> ZLPaletteV2 {
        let i = min(max(index, 0), 6)
        return ZLPaletteV2(
            primary: Color(hex: ZLPaletteDark.primary[i]),
            onPrimary: Color(hex: ZLPaletteDark.onPrimary[i]),
            primaryContainer: Color(hex: ZLPaletteDark.primaryContainer[i]),
            onPrimaryContainer: Color(hex: ZLPaletteDark.onPrimaryContainer[i]),
            secondary: Color(hex: ZLPaletteDark.secondary[i]),
            onSecondary: Color(hex: ZLPaletteDark.onSecondary[i]),
            secondaryContainer: Color(hex: ZLPaletteDark.secondaryContainer[i]),
            onSecondaryContainer: Color(hex: ZLPaletteDark.onSecondaryContainer[i]),
            tertiary: Color(hex: ZLPaletteDark.tertiary[i]),
            onTertiary: Color(hex: ZLPaletteDark.onTertiary[i]),
            tertiaryContainer: Color(hex: ZLPaletteDark.tertiaryContainer[i]),
            onTertiaryContainer: Color(hex: ZLPaletteDark.onTertiaryContainer[i]),
            error: Color(hex: ZLPaletteDark.error[i]),
            onError: Color(hex: ZLPaletteDark.onError[i]),
            errorContainer: Color(hex: ZLPaletteDark.errorContainer[i]),
            onErrorContainer: Color(hex: ZLPaletteDark.onErrorContainer[i]),
            background: Color(hex: ZLPaletteDark.background[i]),
            onBackground: Color(hex: ZLPaletteDark.onBackground[i]),
            surface: Color(hex: ZLPaletteDark.surface[i]),
            onSurface: Color(hex: ZLPaletteDark.onSurface[i]),
            surfaceVariant: Color(hex: ZLPaletteDark.surfaceVariant[i]),
            onSurfaceVariant: Color(hex: ZLPaletteDark.onSurfaceVariant[i]),
            outline: Color(hex: ZLPaletteDark.outline[i]),
            outlineVariant: Color(hex: ZLPaletteDark.outlineVariant[i]),
            scrim: Color(hex: ZLPaletteDark.scrim[i]),
            inverseSurface: Color(hex: ZLPaletteDark.inverseSurface[i]),
            inverseOnSurface: Color(hex: ZLPaletteDark.inverseOnSurface[i]),
            inversePrimary: Color(hex: ZLPaletteDark.inversePrimary[i]),
            surfaceDim: Color(hex: ZLPaletteDark.surfaceDim[i]),
            surfaceBright: Color(hex: ZLPaletteDark.surfaceBright[i]),
            surfaceContainerLowest: Color(hex: ZLPaletteDark.surfaceContainerLowest[i]),
            surfaceContainerLow: Color(hex: ZLPaletteDark.surfaceContainerLow[i]),
            surfaceContainer: Color(hex: ZLPaletteDark.surfaceContainer[i]),
            surfaceContainerHigh: Color(hex: ZLPaletteDark.surfaceContainerHigh[i]),
            surfaceContainerHighest: Color(hex: ZLPaletteDark.surfaceContainerHighest[i]),
        )
    }
}

