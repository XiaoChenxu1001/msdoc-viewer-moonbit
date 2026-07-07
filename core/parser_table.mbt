///| Table construction from parsed paragraphs

///| Extracted from parser.mbt for better organization

///|
/// Get table nesting depth from paragraph
pub fn get_para_table_depth(para : ParagraphInfo) -> Int {
  if !para.in_table {
    return 0
  }
  if para.itap > 0 {
    para.itap
  } else if para.dtap > 0 {
    para.dtap
  } else {
    1
  }
}

///|
/// Build blocks from paragraphs, grouping table paragraphs
pub fn build_blocks(
  paragraphs : Array[ParagraphInfo],
  styles : StyleCollection,
) -> Array[Block] {
  let blocks = Array::new()
  let mut index = 0
  while index < paragraphs.length() {
    let para = paragraphs[index]
    let depth = get_para_table_depth(para)
    if depth <= 0 {
      blocks.push(Block::Paragraph(para))
      index += 1
      continue
    }
    let table_paras = Array::new()
    while index < paragraphs.length() &&
          get_para_table_depth(paragraphs[index]) > 0 {
      table_paras.push(paragraphs[index])
      index += 1
    }
    let table = build_table_block(table_paras, depth, styles)
    blocks.push(Block::Table(table))
  }
  blocks
}

///|
/// Build a table block from table paragraphs
pub fn build_table_block(
  paras : Array[ParagraphInfo],
  depth : Int,
  styles : StyleCollection,
) -> TableBlock {
  let rows = Array::new()
  let mut current_cell_paras = Array::new()
  let mut current_row_cells = Array::new()
  let mut pending_table_state : TableState? = None

  for para in paras {
    // Detect table state with style inheritance (matches JS buildParagraphModel)
    if pending_table_state is None &&
      para.itap >= 1 &&
      para.raw_papx.length() > 0 {
      let raw_view = para.raw_papx.view()
      let decoded = decode_grpprl(raw_view)
      let direct_ts = table_props_from_decoded_impl(decoded, para.raw_papx)
      // Resolve table style inheritance
      let final_ts = if direct_ts.style_id > 0 {
        let resolved = resolve_style(styles, direct_ts.style_id)
        let merged = merge_property_arrays([resolved.table_props, decoded])
        let merged_ts = table_props_from_decoded(merged)
        // Preserve defTable bytes from direct scan (merged loses raw bytes)
        if merged_ts.def_table_bytes.length() == 0 &&
          direct_ts.def_table_bytes.length() > 0 {
          TableState::{
            style_id: merged_ts.style_id,
            indent: merged_ts.indent,
            cell_margins: merged_ts.cell_margins,
            grid_columns: merged_ts.grid_columns,
            left_indent: merged_ts.left_indent,
            row_height: merged_ts.row_height,
            alignment: merged_ts.alignment,
            table_width: merged_ts.table_width,
            def_table_bytes: direct_ts.def_table_bytes,
            operations: merged_ts.operations,
            table_shading: merged_ts.table_shading,
            cell_padding: merged_ts.cell_padding,
          }
        } else {
          merged_ts
        }
      } else {
        direct_ts
      }
      if final_ts.def_table_bytes.length() > 0 {
        pending_table_state = Some(final_ts)
      }
    }

    current_cell_paras.push(para)

    let is_cell_end = para.terminator == b'\x07'
    let is_row_end = para.table_row_end || para.inner_table_row_end

    if is_cell_end {
      current_row_cells.push(DocTableCell::{
        paragraphs: current_cell_paras,
        meta: None,
        col_index: current_row_cells.length(),
        colspan: 1,
        rowspan: 1,
        hidden: false,
      })
      current_cell_paras = Array::new()

      if is_row_end {
        // Resolve table state with style inheritance (matches JS buildParagraphModel)
        let raw_view2 = para.raw_papx.view()
        let decoded2 = decode_grpprl(raw_view2)
        let direct_ts2 = table_props_from_decoded_impl(decoded2, para.raw_papx)
        let row_ts = if direct_ts2.style_id > 0 {
          let resolved2 = resolve_style(styles, direct_ts2.style_id)
          let merged2 = merge_property_arrays([resolved2.table_props, decoded2])
          let merged_ts2 = table_props_from_decoded(merged2)
          if merged_ts2.def_table_bytes.length() == 0 &&
            direct_ts2.def_table_bytes.length() > 0 {
            TableState::{
              style_id: merged_ts2.style_id,
              indent: merged_ts2.indent,
              cell_margins: merged_ts2.cell_margins,
              grid_columns: merged_ts2.grid_columns,
              left_indent: merged_ts2.left_indent,
              row_height: merged_ts2.row_height,
              alignment: merged_ts2.alignment,
              table_width: merged_ts2.table_width,
              def_table_bytes: direct_ts2.def_table_bytes,
              operations: merged_ts2.operations,
              table_shading: merged_ts2.table_shading,
              cell_padding: merged_ts2.cell_padding,
            }
          } else {
            merged_ts2
          }
        } else {
          direct_ts2
        }
        let effective_ts = if row_ts.def_table_bytes.length() > 0 {
          pending_table_state = Some(row_ts)
          row_ts
        } else {
          match pending_table_state {
            Some(ts) => ts
            None => row_ts
          }
        }
        // Apply cell definitions to this row
        let cell_defs = apply_table_state_to_cells(effective_ts)
        // Prune empty trailing cells (matches JS: pendingRow.cells.pop() while empty)
        if cell_defs.length() > 0 &&
          cell_defs.length() < current_row_cells.length() {
          while current_row_cells.length() > cell_defs.length() {
            let last_cell = current_row_cells[current_row_cells.length() - 1]
            let mut is_empty = true
            for p in last_cell.paragraphs {
              // Check if paragraph has meaningful content (not just control chars like 0x07)
              let mut has_content = false
              for r in p.runs {
                let mut has_non_control = false
                let mut ci2 = 0
                while ci2 < r.text.length() {
                  let tc = r.text[ci2].to_int()
                  if tc != 0x07 && tc != 0x13 && tc != 0x14 && tc != 0x15 {
                    has_non_control = true
                    break
                  }
                  ci2 += 1
                }
                if has_non_control ||
                  r.is_line_break ||
                  r.is_page_break ||
                  r.href.length() > 0 {
                  has_content = true
                  break
                }
              }
              if has_content {
                is_empty = false
                break
              }
            }
            if is_empty {
              ignore(current_row_cells.pop())
            } else {
              break
            }
          }
        }
        let final_cells = if cell_defs.length() > 0 {
          let new_cells = Array::new()
          let mut ci = 0
          while ci < current_row_cells.length() && ci < cell_defs.length() {
            let old_cell = current_row_cells[ci]
            new_cells.push(DocTableCell::{
              paragraphs: old_cell.paragraphs,
              meta: Some(cell_defs[ci]),
              col_index: old_cell.col_index,
              colspan: 1,
              rowspan: 1,
              hidden: false,
            })
            ci += 1
          }
          while ci < current_row_cells.length() {
            new_cells.push(current_row_cells[ci])
            ci += 1
          }
          new_cells
        } else {
          current_row_cells
        }
        rows.push(TableRow::{
          cells: final_cells,
          grid_width_twips: if cell_defs.length() > 0 {
            cell_defs[cell_defs.length() - 1].right_boundary -
            cell_defs[0].left_boundary
          } else {
            0
          },
          row_height: effective_ts.row_height,
        })
        current_row_cells = Array::new()
      }
    }
  }
  if current_cell_paras.length() > 0 {
    current_row_cells.push(DocTableCell::{
      paragraphs: current_cell_paras,
      meta: None,
      col_index: current_row_cells.length(),
      colspan: 1,
      rowspan: 1,
      hidden: false,
    })
  }
  if current_row_cells.length() > 0 {
    let last_rh = match pending_table_state {
      Some(ts) => ts.row_height
      None => 0
    }
    rows.push(TableRow::{
      cells: current_row_cells,
      grid_width_twips: 0,
      row_height: last_rh,
    })
  }

  if rows.length() == 0 {
    let cells = Array::new()
    for para in paras {
      cells.push(DocTableCell::{
        paragraphs: Array::makei(1, fn(_i) { para }),
        meta: None,
        col_index: cells.length(),
        colspan: 1,
        rowspan: 1,
        hidden: false,
      })
    }
    rows.push(TableRow::{ cells, grid_width_twips: 0, row_height: 0 })
  }

  // Apply table state to remaining rows without meta (trailing row without row_end marker)
  match pending_table_state {
    Some(ts) => {
      let cell_defs = apply_table_state_to_cells(ts)
      if cell_defs.length() > 0 {
        for ri in 0..<rows.length() {
          let row = rows[ri]
          // Skip rows already processed (cells have meta from per-paragraph resolution)
          let already_processed = if row.cells.length() > 0 {
            match row.cells[0].meta {
              Some(_) => true
              None => false
            }
          } else {
            false
          }
          if already_processed {
            continue
          }
          if cell_defs.length() < row.cells.length() {
            while row.cells.length() > cell_defs.length() {
              let last_cell = row.cells[row.cells.length() - 1]
              let mut is_empty = true
              for p in last_cell.paragraphs {
                if p.text.length() > 0 || p.runs.length() > 0 {
                  is_empty = false
                  break
                }
              }
              if is_empty {
                ignore(row.cells.pop())
              } else {
                break
              }
            }
          }
          let new_cells = Array::new()
          let mut ci = 0
          let def_count = cell_defs.length()
          while ci < row.cells.length() && ci < def_count {
            let def = cell_defs[ci]
            let old_cell = row.cells[ci]
            ignore(def.right_boundary - def.left_boundary)
            new_cells.push(DocTableCell::{
              paragraphs: old_cell.paragraphs,
              meta: Some(def),
              col_index: old_cell.col_index,
              colspan: 1,
              rowspan: 1,
              hidden: false,
            })
            ci += 1
          }
          rows[ri] = TableRow::{
            cells: new_cells,
            grid_width_twips: if cell_defs.length() > 0 {
              cell_defs[cell_defs.length() - 1].right_boundary -
              cell_defs[0].left_boundary
            } else {
              0
            },
            row_height: rows[ri].row_height,
          }
        }
      }
    }
    None => ignore(0)
  }

  // Finalize merge grid (colspan, rowspan, hidden)
  finalize_table_grid(rows)

  TableBlock::{ rows, depth, table_state: pending_table_state }
}

///|
/// Finalize table grid: compute horizontal merge (colspan) and vertical merge (rowspan)
fn finalize_table_grid(rows : Array[TableRow]) -> Unit {
  if rows.length() == 0 {
    return
  }

  // Find maximum column count across all rows
  let mut max_cols = 0
  for ri in 0..<rows.length() {
    let row = rows[ri]
    let mut visible_count = 0
    for ci in 0..<row.cells.length() {
      if !row.cells[ci].hidden {
        visible_count += 1
      }
    }
    if visible_count > max_cols {
      max_cols = visible_count
    }
  }

  // Pass 1: Horizontal merge (colspan) based on merge values
  for ri in 0..<rows.length() {
    let row = rows[ri]
    let mut ci = 0
    while ci < row.cells.length() {
      let cell = row.cells[ci]
      let merge_val = match cell.meta {
        Some(def) => def.merge
        None => 0
      }
      if merge_val == 1 {
        rows[ri].cells[ci] = DocTableCell::{
          paragraphs: cell.paragraphs,
          meta: cell.meta,
          col_index: cell.col_index,
          colspan: cell.colspan,
          rowspan: cell.rowspan,
          hidden: true,
        }
      } else if merge_val == 2 {
        let mut cs = 1
        let mut j = ci + 1
        while j < row.cells.length() {
          let next_cell = row.cells[j]
          let next_merge = match next_cell.meta {
            Some(def) => def.merge
            None => 0
          }
          if next_merge == 1 {
            rows[ri].cells[j] = DocTableCell::{
              paragraphs: next_cell.paragraphs,
              meta: next_cell.meta,
              col_index: next_cell.col_index,
              colspan: next_cell.colspan,
              rowspan: next_cell.rowspan,
              hidden: true,
            }
            cs = cs + 1
            j += 1
          } else {
            break
          }
        }
        rows[ri].cells[ci] = DocTableCell::{
          paragraphs: cell.paragraphs,
          meta: cell.meta,
          col_index: cell.col_index,
          colspan: cell.colspan,
          rowspan: cell.rowspan,
          hidden: true,
        }
      }
      ci += 1
    }
  }

  // Pass 2: Auto-colspan for rows with fewer cells than max_cols
  // When a row has fewer cells than max_cols, the last cell should span the remaining columns
  for ri in 0..<rows.length() {
    let row = rows[ri]
    let mut visible_count = 0
    for ci in 0..<row.cells.length() {
      if !row.cells[ci].hidden {
        visible_count += 1
      }
    }
    // If this row has fewer visible cells than max_cols, the last visible cell should span the difference
    if visible_count > 0 && visible_count < max_cols {
      let last_visible_idx = {
        let mut idx = -1
        for ci in 0..<row.cells.length() {
          if !row.cells[ci].hidden {
            idx = ci
          }
        }
        idx
      }
      if last_visible_idx >= 0 {
        let extra_cols = max_cols - visible_count
        let current_colspan = rows[ri].cells[last_visible_idx].colspan
        rows[ri].cells[last_visible_idx] = DocTableCell::{
          paragraphs: rows[ri].cells[last_visible_idx].paragraphs,
          meta: rows[ri].cells[last_visible_idx].meta,
          col_index: rows[ri].cells[last_visible_idx].col_index,
          colspan: current_colspan + extra_cols,
          rowspan: rows[ri].cells[last_visible_idx].rowspan,
          hidden: false,
        }
      }
    }
  }

  // Pass 3: Vertical merge (rowspan)
  for ri in 0..<rows.length() {
    let row = rows[ri]
    for ci in 0..<row.cells.length() {
      let cell = row.cells[ci]
      if cell.hidden {
        continue
      }
      let vmerge_val = match cell.meta {
        Some(def) => def.vert_merge
        None => 0
      }
      if vmerge_val == 1 {
        rows[ri].cells[ci] = DocTableCell::{
          paragraphs: cell.paragraphs,
          meta: cell.meta,
          col_index: cell.col_index,
          colspan: cell.colspan,
          rowspan: cell.rowspan,
          hidden: true,
        }
      } else if vmerge_val > 1 {
        let mut rs = 1
        let mut k = ri + 1
        while k < rows.length() {
          let below_row = rows[k]
          let cell_col = cell.col_index
          let cell_span = cell.colspan
          let mut can_merge = true
          let mut col = cell_col
          while col < cell_col + cell_span {
            if col >= below_row.cells.length() {
              can_merge = false
              break
            }
            let below_cell = below_row.cells[col]
            let below_vmerge = match below_cell.meta {
              Some(def) => def.vert_merge
              None => 0
            }
            if below_vmerge != 1 {
              can_merge = false
              break
            }
            col += 1
          }
          if !can_merge {
            break
          }
          let mut col2 = cell_col
          while col2 < cell_col + cell_span {
            let below_cell = below_row.cells[col2]
            rows[k].cells[col2] = DocTableCell::{
              paragraphs: below_cell.paragraphs,
              meta: below_cell.meta,
              col_index: below_cell.col_index,
              colspan: below_cell.colspan,
              rowspan: below_cell.rowspan,
              hidden: true,
            }
            col2 += 1
          }
          rs = rs + 1
          k += 1
        }
        rows[ri].cells[ci] = DocTableCell::{
          paragraphs: cell.paragraphs,
          meta: cell.meta,
          col_index: cell.col_index,
          colspan: cell.colspan,
          rowspan: rs,
          hidden: false,
        }
      }
    }
  }
}
