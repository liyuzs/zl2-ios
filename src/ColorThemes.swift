// ZL2-iOS · 主题色板（从 ZL2 Color.kt 逐项还原）
// 来源：ZalithLauncher/ui/theme/Color.kt —— 7 套主题 × 35 组 × 亮/暗
import SwiftUI

enum ZLColorTheme: String, CaseIterable, Identifiable {
    case embermire = "釉烬"
    case velvetRose = "绒玫"
    case mistwave = "雾澜"
    case glacier = "冰川"
    case verdantField = "原野暮光"
    case urbanAsh = "钛影"
    case verdantDawn = "静林之晨"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var index: Int {
        switch self {
        case .embermire: return 0
        case .velvetRose: return 1
        case .mistwave: return 2
        case .glacier: return 3
        case .verdantField: return 4
        case .urbanAsh: return 5
        case .verdantDawn: return 6
        }
    }

    var primary: Color { ZLPalette.color("primaryLight", index) }
    var onPrimary: Color { ZLPalette.color("onPrimaryLight", index) }
    var primaryContainer: Color { ZLPalette.color("primaryContainerLight", index) }
    var secondary: Color { ZLPalette.color("secondaryLight", index) }
    var background: Color { ZLPalette.color("backgroundLight", index) }
    var surface: Color { ZLPalette.color("surfaceLight", index) }
    var onSurface: Color { ZLPalette.color("onSurfaceLight", index) }
    var onSurfaceVariant: Color { ZLPalette.color("onSurfaceVariantLight", index) }
    var outline: Color { ZLPalette.color("outlineLight", index) }
    var surfaceContainer: Color { ZLPalette.color("surfaceContainerLight", index) }
    var surfaceContainerHigh: Color { ZLPalette.color("surfaceContainerHighLight", index) }
    var onPrimaryContainer: Color { ZLPalette.color("onPrimaryContainerLight", index) }
    var secondaryContainer: Color { ZLPalette.color("secondaryContainerLight", index) }
    var onSecondary: Color { ZLPalette.color("onSecondaryLight", index) }
    var tertiary: Color { ZLPalette.color("tertiaryLight", index) }
    var primaryDark: Color { ZLPalette.color("primaryDark", index) }
    var backgroundDark: Color { ZLPalette.color("backgroundDark", index) }
    var surfaceDark: Color { ZLPalette.color("surfaceDark", index) }
    var onSurfaceDark: Color { ZLPalette.color("onSurfaceDark", index) }
}

enum ZLPalette {
    static let raw: [String: [UInt32]] = [
        "primaryLight": [0xFFA63A17, 0xFF723D57, 0xFF426469, 0xFF006684, 0xFF676014, 0xFF5E5E5F, 0xFF004814],
        "onPrimaryLight": [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF],
        "primaryContainerLight": [0xFFFE7A52, 0xFF9B607C, 0xFFB1D5DB, 0xFF4CAFD6, 0xFFEFE58B, 0xFFAEAEAE, 0xFF276E31],
        "onPrimaryContainerLight": [0xFF2F0700, 0xFFFFFFFF, 0xFF1E4146, 0xFF001B26, 0xFF1F1C00, 0xFF222324, 0xFFFFFFFF],
        "secondaryLight": [0xFF894F3D, 0xFF725762, 0xFF546163, 0xFF426372, 0xFF635F41, 0xFF5F5E5E, 0xFF4A6548],
        "onSecondaryLight": [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF],
        "secondaryContainerLight": [0xFFFFBBA7, 0xFFFFDAE8, 0xFFD8E6E9, 0xFFCAECFE, 0xFFEAE3BE, 0xFFE8E6E5, 0xFFCFEFCA],
        "onSecondaryContainerLight": [0xFF5C2B1C, 0xFF5B414D, 0xFF3E4B4D, 0xFF2E4F5D, 0xFF1E1C05, 0xFF4A4A4A, 0xFF365135],
        "tertiaryLight": [0xFF6E5E00, 0xFF773F27, 0xFF655975, 0xFF794C91, 0xFF406653, 0xFF615D5F, 0xFF003C77],
        "onTertiaryLight": [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF],
        "tertiaryContainerLight": [0xFFBAA015, 0xFFA26247, 0xFFD8C9E9, 0xFFC390DB, 0xFFC1ECD4, 0xFFB2ADAF, 0xFF2960A6],
        "onTertiaryContainerLight": [0xFF1A1500, 0xFFFFFFFF, 0xFF423751, 0xFF2B0041, 0xFF002114, 0xFF252324, 0xFFFFFFFF],
        "errorLight": [0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A, 0xFFBA1A1A],
        "onErrorLight": [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF],
        "errorContainerLight": [0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6],
        "onErrorContainerLight": [0xFF410002, 0xFF410002, 0xFF410002, 0xFF410002, 0xFF410002, 0xFF410002, 0xFF410002],
        "backgroundLight": [0xFFFFF8F6, 0xFFFFF8F8, 0xFFFAF9F9, 0xFFF6FAFD, 0xFFFEF9EB, 0xFFFCF8F8, 0xFFF7FBF2],
        "onBackgroundLight": [0xFF241916, 0xFF1F1A1C, 0xFF1A1C1C, 0xFF181C1F, 0xFF1D1C14, 0xFF1C1B1B, 0xFF181D18],
        "surfaceLight": [0xFFFFF8F6, 0xFFFFF8F8, 0xFFFAF9F9, 0xFFF6FAFD, 0xFFFEF9EB, 0xFFFCF8F8, 0xFFF7FBF2],
        "onSurfaceLight": [0xFF241916, 0xFF1F1A1C, 0xFF1A1C1C, 0xFF181C1F, 0xFF1D1C14, 0xFF1C1B1B, 0xFF181D18],
        "surfaceVariantLight": [0xFFFCDBD3, 0xFFF1DEE4, 0xFFDDE4E5, 0xFFDAE4EA, 0xFFE7E3D0, 0xFFE0E3E3, 0xFFDCE5D7],
        "onSurfaceVariantLight": [0xFF58423B, 0xFF504348, 0xFF414849, 0xFF3E484E, 0xFF49473A, 0xFF444748, 0xFF40493E],
        "outlineLight": [0xFF8B716A, 0xFF827378, 0xFF71787A, 0xFF6E797E, 0xFF7A7768, 0xFF747878, 0xFF707A6D],
        "outlineVariantLight": [0xFFDFC0B7, 0xFFD4C2C8, 0xFFC1C8C9, 0xFFBEC8CE, 0xFFCBC7B5, 0xFFC4C7C7, 0xFFC0C9BB],
        "scrimLight": [0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000],
        "inverseSurfaceLight": [0xFF3B2D2A, 0xFF352F31, 0xFF2F3131, 0xFF2D3134, 0xFF323128, 0xFF313030, 0xFF2D322C],
        "inverseOnSurfaceLight": [0xFFFFEDE8, 0xFFF9EEF0, 0xFFF1F1F0, 0xFFEEF1F4, 0xFFF5F0E3, 0xFFF4F0EF, 0xFFEEF2E9],
        "inversePrimaryLight": [0xFFFFB59F, 0xFFF9B2D2, 0xFFA9CDD3, 0xFF73D2FB, 0xFFD2C972, 0xFFC7C6C6, 0xFF8ED88E],
        "surfaceDimLight": [0xFFEBD5D0, 0xFFE2D7DA, 0xFFDADADA, 0xFFD7DADE, 0xFFDEDACC, 0xFFDDD9D9, 0xFFD8DBD3],
        "surfaceBrightLight": [0xFFFFF8F6, 0xFFFFF8F8, 0xFFFAF9F9, 0xFFF6FAFD, 0xFFFEF9EB, 0xFFFCF8F8, 0xFFF7FBF2],
        "surfaceContainerLowestLight": [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF],
        "surfaceContainerLowLight": [0xFFFFF1ED, 0xFFFCF1F3, 0xFFF4F3F3, 0xFFF0F4F7, 0xFFF8F3E6, 0xFFF7F3F2, 0xFFF1F5EC],
        "surfaceContainerLight": [0xFFFFE9E4, 0xFFF7EBED, 0xFFEEEEEE, 0xFFEBEEF1, 0xFFF2EEE0, 0xFFF1EDEC, 0xFFECEFE6],
        "surfaceContainerHighLight": [0xFFFAE3DD, 0xFFF1E5E8, 0xFFE8E8E8, 0xFFE5E9EC, 0xFFEDE8DA, 0xFFEBE7E7, 0xFFE6E9E1],
        "surfaceContainerHighestLight": [0xFFF4DED8, 0xFFEBE0E2, 0xFFE3E2E2, 0xFFDFE3E6, 0xFFE7E2D5, 0xFFE5E2E1, 0xFFE0E4DB],
        "primaryDark": [0xFFFFB59F, 0xFFF9B2D2, 0xFFCEF3F9, 0xFF73D2FB, 0xFFD2C972, 0xFFC7C6C6, 0xFF8ED88E],
        "onPrimaryDark": [0xFF5F1600, 0xFF4F2039, 0xFF11353A, 0xFF003546, 0xFF353100, 0xFF2F3131, 0xFF00390F],
        "primaryContainerDark": [0xFFC4502B, 0xFF915873, 0xFFA5C9CF, 0xFF007EA2, 0xFF4E4800, 0xFF9B9B9B, 0xFF005219],
        "onPrimaryContainerDark": [0xFFFFFFFF, 0xFFFFFFFF, 0xFF14383D, 0xFFFFFFFF, 0xFFEFE58B, 0xFF0B0C0D, 0xFFA6F2A5],
        "secondaryDark": [0xFFFFB59F, 0xFFE0BDCB, 0xFFBBC9CB, 0xFFAACBDD, 0xFFCDC7A3, 0xFFC8C6C6, 0xFFB0CFAB],
        "onSecondaryDark": [0xFF512214, 0xFF412A34, 0xFF263335, 0xFF113442, 0xFF343117, 0xFF303030, 0xFF1C361D],
        "secondaryContainerDark": [0xFF643122, 0xFF4F3641, 0xFF333F41, 0xFF204250, 0xFF4B482C, 0xFF3D3D3D, 0xFF294329],
        "onSecondaryContainerDark": [0xFFFFC8B9, 0xFFEBC7D5, 0xFFC5D3D6, 0xFFB4D6E8, 0xFFEAE3BE, 0xFFD3D0D0, 0xFFB9D9B5],
        "tertiaryDark": [0xFFF0D44C, 0xFFFFB598, 0xFFF5E9FF, 0xFFE7B3FF, 0xFFA6D0B9, 0xFFCBC5C7, 0xFFA7C8FF],
        "onTertiaryDark": [0xFF393000, 0xFF52220C, 0xFF362C45, 0xFF471C5F, 0xFF0F3727, 0xFF323031, 0xFF003061],
        "tertiaryContainerDark": [0xFFC4AA22, 0xFF97593F, 0xFFCCBDDD, 0xFFAF7EC7, 0xFF284E3C, 0xFFA09B9D, 0xFF004688],
        "onTertiaryContainerDark": [0xFF272000, 0xFFFFFFFF, 0xFF392F48, 0xFF000000, 0xFFC1ECD4, 0xFF0F0D0F, 0xFFD1E0FF],
        "errorDark": [0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB, 0xFFFFB4AB],
        "onErrorDark": [0xFF690005, 0xFF690005, 0xFF690005, 0xFF690005, 0xFF690005, 0xFF690005, 0xFF690005],
        "errorContainerDark": [0xFF93000A, 0xFF93000A, 0xFF93000A, 0xFF93000A, 0xFF93000A, 0xFF93000A, 0xFF93000A],
        "onErrorContainerDark": [0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6, 0xFFFFDAD6],
        "backgroundDark": [0xFF1C110E, 0xFF171214, 0xFF121414, 0xFF101416, 0xFF15140C, 0xFF141313, 0xFF101410],
        "onBackgroundDark": [0xFFF4DED8, 0xFFEBE0E2, 0xFFE3E2E2, 0xFFDFE3E6, 0xFFE7E2D5, 0xFFE5E2E1, 0xFFE0E4DB],
        "surfaceDark": [0xFF1C110E, 0xFF171214, 0xFF121414, 0xFF101416, 0xFF15140C, 0xFF141313, 0xFF101410],
        "onSurfaceDark": [0xFFF4DED8, 0xFFEBE0E2, 0xFFE3E2E2, 0xFFDFE3E6, 0xFFE7E2D5, 0xFFE5E2E1, 0xFFE0E4DB],
        "surfaceVariantDark": [0xFF58423B, 0xFF504348, 0xFF414849, 0xFF3E484E, 0xFF49473A, 0xFF444748, 0xFF40493E],
        "onSurfaceVariantDark": [0xFFDFC0B7, 0xFFD4C2C8, 0xFFC1C8C9, 0xFFBEC8CE, 0xFFCBC7B5, 0xFFC4C7C7, 0xFFC0C9BB],
        "outlineDark": [0xFFA68B83, 0xFF9D8C92, 0xFF8B9293, 0xFF889298, 0xFF949181, 0xFF8E9192, 0xFF8A9386],
        "outlineVariantDark": [0xFF58423B, 0xFF504348, 0xFF414849, 0xFF3E484E, 0xFF49473A, 0xFF444748, 0xFF40493E],
        "scrimDark": [0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000],
        "inverseSurfaceDark": [0xFFF4DED8, 0xFFEBE0E2, 0xFFE3E2E2, 0xFFDFE3E6, 0xFFE7E2D5, 0xFFE5E2E1, 0xFFE0E4DB],
        "inverseOnSurfaceDark": [0xFF3B2D2A, 0xFF352F31, 0xFF2F3131, 0xFF2D3134, 0xFF323128, 0xFF313030, 0xFF2D322C],
        "inversePrimaryDark": [0xFFA63A17, 0xFF854D68, 0xFF426469, 0xFF006684, 0xFF676014, 0xFF5E5E5F, 0xFF246C2F],
        "surfaceDimDark": [0xFF1C110E, 0xFF171214, 0xFF121414, 0xFF101416, 0xFF15140C, 0xFF141313, 0xFF101410],
        "surfaceBrightDark": [0xFF443632, 0xFF3E373A, 0xFF38393A, 0xFF353A3C, 0xFF3B3930, 0xFF3A3939, 0xFF363A34],
        "surfaceContainerLowestDark": [0xFF160C09, 0xFF120D0F, 0xFF0D0E0F, 0xFF0A0F11, 0xFF0F0E07, 0xFF0E0E0E, 0xFF0B0F0B],
        "surfaceContainerLowDark": [0xFF241916, 0xFF1F1A1C, 0xFF1A1C1C, 0xFF181C1F, 0xFF1D1C14, 0xFF1C1B1B, 0xFF181D18],
        "surfaceContainerDark": [0xFF291D19, 0xFF241E20, 0xFF1E2020, 0xFF1C2023, 0xFF212017, 0xFF201F1F, 0xFF1C211B],
        "surfaceContainerHighDark": [0xFF342723, 0xFF2E282A, 0xFF292A2A, 0xFF262B2D, 0xFF2C2A21, 0xFF2A2A2A, 0xFF272B26],
        "surfaceContainerHighestDark": [0xFF3F322E, 0xFF393335, 0xFF333535, 0xFF313538, 0xFF37352C, 0xFF353434, 0xFF323630],
    ]

    static func color(_ group: String, _ index: Int) -> Color {
        guard let arr = raw[group], index >= 0, index < arr.count else { return .gray }
        return Color(hex: arr[index])
    }
}