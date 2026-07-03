///| MS-DOC parser type definitions
///| Extracted from parser.mbt for better organization

///| Render run (text span with formatting)
pub struct RenderRun {
  text : String
  bold : Bool
  italic : Bool
  underline : Int
  strike : Bool
  double_strike : Bool
  font_size : Int
  font_family : String
  color : Int
  highlight : Int
  superscript : Bool
  subscript : Bool
  href : String
  bold_bi : Bool
  italic_bi : Bool
  small_caps : Bool
  caps : Bool
  outline : Bool
  shadow : Bool
  emboss : Bool
  imprint : Bool
  scale : Int
  position_half_points : Int
  rtl : Bool
  is_line_break : Bool
  is_page_break : Bool
  is_image : Bool
  image_data_url : String
  image_width : Int
  image_height : Int
  is_attachment : Bool
  attachment_name : String
}

///| Paragraph info with formatting
pub struct ParagraphInfo {
  cp_start : Int
  cp_end : Int
  text : String
  runs : Array[RenderRun]
  style_name : String
  align : Int
  indent_left : Int
  indent_right : Int
  indent_first : Int
  space_before : Int
  space_after : Int
  line_spacing : Int
  keep_with_next : Bool
  keep_together : Bool
  page_break_before : Bool
  itap : Int
  table_row_end : Bool
  inner_table_cell : Bool
  inner_table_row_end : Bool
  in_table : Bool
  dtap : Int
  rtl_para : Bool
  terminator : Byte
  raw_papx : Array[Byte]
  border_top : Int
  border_left : Int
  border_bottom : Int
  border_right : Int
  outline_level : Int
  shading : Int
}

///| Table cell (parser)
pub struct DocTableCell {
  paragraphs : Array[ParagraphInfo]
  meta : Option[TableCellDef]
  col_index : Int
  colspan : Int
  rowspan : Int
  hidden : Bool
}

///| Table row
pub struct TableRow {
  cells : Array[DocTableCell]
  grid_width_twips : Int
  row_height : Int
}

///| Table block
pub struct TableBlock {
  rows : Array[TableRow]
  depth : Int
  table_state : Option[TableState]
}

///| Block - either a paragraph, a table, or trailing attachments
pub struct Block {
  paragraph : Option[ParagraphInfo]
  table : Option[TableBlock]
  attachments : Option[Array[Asset]]
}

///| Parse result
pub struct MsDocParseResult {
  text : String
  paragraphs : Array[ParagraphInfo]
  blocks : Array[Block]
  warnings : Array[String]
  assets : Array[Asset]
  meta : Option[ParseMeta]
  fonts : Array[FontInfo]
  styles : Array[StyleInfo]
  textboxes : Array[TextBox]
  headers : Array[HeaderFooter]
  footers : Array[HeaderFooter]
  sections : Array[SectionProperties]
  footnotes : Array[Footnote]
  endnotes : Array[Footnote]
  raw_data : FixedArray[Byte]
  image_config : ImageProcessorConfig
  image_cache : Map[Int, Asset]
  content_dedup_cache : Map[String, Asset]
}

///| Deferred parse result with image extraction context
///| Contains both the parse result and the data needed for async image extraction
pub struct DeferredParseResult {
  result : MsDocParseResult
  data_bytes : FixedArray[Byte]
  image_config : ImageProcessorConfig
  image_cache : Map[Int, Asset]
}

///| Parse metadata (mirrors JS meta object)
pub struct ParseMeta {
  fib_w_ident : Int
  fib_n_fib : Int
  fib_which_tbl_stm : Bool
  fib_complex : Bool
  fib_encrypted : Bool
  ccp_text : Int
  count_paragraphs : Int
  count_blocks : Int
  count_assets : Int
  count_styles : Int
  count_fonts : Int
}

///| Font info for parse result
pub struct FontInfo {
  name : String
  alt_name : String
}

///| Style info for parse result
pub struct StyleInfo {
  istd : Int
  name : String
  style_type : Int
  based_on : Int
  next_style : Int
}

///| Textbox extracted from textbox subdocument
pub struct TextBox {
  shape_id : Int
  text : String
  cp_start : Int
  cp_end : Int
}

///| Header/Footer content
pub struct HeaderFooter {
  text : String
  story_type : Int  // 0=even header, 1=odd header, 2=even footer, 3=odd footer, 4=first header, 5=first footer
  section_index : Int
}

///| Section properties for header/footer control and page layout
pub struct SectionProperties {
  index : Int
  // Header/Footer control
  has_title_page : Bool      // sprmSFTitlePage: first page gets its own header/footer
  header_distance : Int       // sprmSDyaHdrTop: distance from page top to header (twips, default 720)
  footer_distance : Int       // sprmSDyaHdrBottom: distance from page bottom to footer (twips, default 720)
  break_type : Int            // sprmSBkc: section break type (0=continuous, 2=new page)
  // Page layout
  page_width : Int            // sprmSXaPage: page width in twips (default 12240 = 8.5 inches)
  page_height : Int           // sprmSYaPage: page height in twips (default 15840 = 11 inches)
  orientation : Int           // sprmSOrientPage: 0=portrait, 1=landscape
  // Page margins
  margin_top : Int            // sprmSDyaTop: top margin (twips, default 1440 = 1 inch)
  margin_bottom : Int         // sprmSDyaBottom: bottom margin (twips, default 1440)
  margin_left : Int           // sprmSDxaLeft: left margin (twips, default 1800 = 1.25 inches)
  margin_right : Int          // sprmSDxaRight: right margin (twips, default 1800)
  // Columns
  column_count : Int          // sprmNBpc: number of columns (default 1)
  column_spacing : Int        // sprmSClm: space between columns (twips)
}

///| Footnote/Endnote content
pub struct Footnote {
  text : String
  ref_cp : Int      // CP position of the reference mark in main document
  note_index : Int  // 1-based note number
  is_endnote : Bool
}

///| Render result
pub struct RenderResult {
  html : String
  css : String
  warnings : Array[String]
  assets : Array[Asset]
  meta : Option[ParseMeta]
}
