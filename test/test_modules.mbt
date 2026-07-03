// test_modules.mbt - MoonBit模块测试

///| 测试常量模块
test "constants values" {
  // 测试控制字符常量
  assert_eq(@core.DOC_CONTROL_PARAGRAPH, 0x000D)
  assert_eq(@core.DOC_CONTROL_CELL_MARK, 0x0007)
  assert_eq(@core.DOC_CONTROL_PICTURE, 0x0001)

  // 测试下划线映射
  assert_eq(@core.underline_name(0), "none")
  assert_eq(@core.underline_name(1), "single")
  assert_eq(@core.underline_name(3), "double")

  // 测试对齐映射
  assert_eq(@core.alignment_css(0), "left")
  assert_eq(@core.alignment_css(1), "center")
  assert_eq(@core.alignment_css(2), "right")

  // 测试高亮颜色
  assert_eq(@core.highlight_color(1), "#000000")
  assert_eq(@core.highlight_color(6), "#ff0000")

  // 测试特殊扇区ID
  assert_eq(@core.is_special_sector_id(@core.FREESECT), true)
  assert_eq(@core.is_special_sector_id(@core.ENDOFCHAIN), true)
  assert_eq(@core.is_special_sector_id(0), false)
}

///| 测试工具函数模块
test "utils functions" {
  // 测试 clamp
  assert_eq(@core.clamp(5, 0, 10), 5)
  assert_eq(@core.clamp(-5, 0, 10), 0)
  assert_eq(@core.clamp(15, 0, 10), 10)

  // 测试 escape_html
  assert_eq(@core.escape_html("<div>"), "&lt;div&gt;")
  assert_eq(@core.escape_html("a&b"), "a&amp;b")

  // 测试 align_even
  assert_eq(@core.align_even(4), 4)
  assert_eq(@core.align_even(5), 6)

  // 测试 twips_to_px
  assert_eq(@core.twips_to_px(1440, 96), Some(96))
  assert_eq(@core.twips_to_px(720, 96), Some(48))

  // 测试 points_to_px
  assert_eq(@core.points_to_px(72, 96), Some(96))
  assert_eq(@core.points_to_px(36, 96), Some(48))

  // 测试 clean_text_control_chars
  assert_eq(@core.clean_text_control_chars("a\u{000B}b"), "a\nb")
  assert_eq(@core.clean_text_control_chars("a\u{000C}b"), "a\nb")
}
