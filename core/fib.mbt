///| FIB (File Information Block) parser for MS-DOC files

///|
/// FIB base header
pub struct FIBBase {
  w_ident : Int
  n_fib : Int
  lid : Int
  pn_next : Int
  flags : Int
  env_flags : Int
  f_dot : Bool
  f_glsy : Bool
  f_complex : Bool
  f_has_pic : Bool
  c_quick_saves : Int
  f_encrypted : Bool
  f_which_tbl_stm : Int
  f_read_only_recommended : Bool
  f_write_reservation : Bool
  f_ext_char : Bool
  f_load_override : Bool
  f_far_east : Bool
  f_obfuscated : Bool
  n_fib_back : Int
  l_key : Int
  envr : Int
  f_mac : Bool
  f_empty_special : Bool
  f_load_override_page : Bool
}

///|
/// FIB long word values
pub struct FIBRgLw {
  raw : Array[Int]
  cb_mac : Int
  ccp_text : Int
  ccp_ftn : Int
  ccp_hdd : Int
  ccp_mcr : Int
  ccp_atn : Int
  ccp_edn : Int
  ccp_txbx : Int
  ccp_hdr_txbx : Int
}

///|
/// FC/LCB pair
pub struct FcLcbPair {
  name : String
  fc : Int
  lcb : Int
  index : Int
}

///|
/// FIB FC/LCB table
pub struct FIBRgFcLcb {
  pairs : Array[FcLcbPair]
  fc_stshf_orig : Int
  lcb_stshf_orig : Int
  fc_stshf : Int
  lcb_stshf : Int
  fc_plcffnd_ref : Int
  lcb_plcffnd_ref : Int
  fc_plcffnd_txt : Int
  lcb_plcffnd_txt : Int
  fc_plcfand_ref : Int
  lcb_plcfand_ref : Int
  fc_plcfand_txt : Int
  lcb_plcfand_txt : Int
  fc_plcf_sed : Int
  lcb_plcf_sed : Int
  fc_plc_pad : Int
  lcb_plc_pad : Int
  fc_plcf_phe : Int
  lcb_plcf_phe : Int
  fc_sttbf_glsy : Int
  lcb_sttbf_glsy : Int
  fc_plcf_glsy : Int
  lcb_plcf_glsy : Int
  fc_plcf_hdd : Int
  lcb_plcf_hdd : Int
  fc_plcf_bte_chpx : Int
  lcb_plcf_bte_chpx : Int
  fc_plcf_bte_papx : Int
  lcb_plcf_bte_papx : Int
  fc_plcf_sea : Int
  lcb_plcf_sea : Int
  fc_sttbf_ffn : Int
  lcb_sttbf_ffn : Int
  fc_plcf_fld_mom : Int
  lcb_plcf_fld_mom : Int
  fc_plcf_fld_hdr : Int
  lcb_plcf_fld_hdr : Int
  fc_plcf_fld_ftn : Int
  lcb_plcf_fld_ftn : Int
  fc_plcf_fld_atn : Int
  lcb_plcf_fld_atn : Int
  fc_plcf_fld_mcr : Int
  lcb_plcf_fld_mcr : Int
  fc_sttbf_bkmk : Int
  lcb_sttbf_bkmk : Int
  fc_plcf_bkf : Int
  lcb_plcf_bkf : Int
  fc_plcf_bkl : Int
  lcb_plcf_bkl : Int
  fc_cmds : Int
  lcb_cmds : Int
  fc_sttbf_mcr : Int
  lcb_sttbf_mcr : Int
  fc_pr_drvr : Int
  lcb_pr_drvr : Int
  fc_pr_env_port : Int
  lcb_pr_env_port : Int
  fc_pr_env_land : Int
  lcb_pr_env_land : Int
  fc_wss : Int
  lcb_wss : Int
  fc_dop : Int
  lcb_dop : Int
  fc_sttbf_assoc : Int
  lcb_sttbf_assoc : Int
  fc_clx : Int
  lcb_clx : Int
  fc_plcf_pgd_ftn : Int
  lcb_plcf_pgd_ftn : Int
  fc_autosave_source : Int
  lcb_autosave_source : Int
  fc_grp_xst_atn_owners : Int
  lcb_grp_xst_atn_owners : Int
  fc_sttbf_atn_bkmk : Int
  lcb_sttbf_atn_bkmk : Int
  fc_plcf_spa_mom : Int
  lcb_plcf_spa_mom : Int
  fc_plcf_spa_hdr : Int
  lcb_plcf_spa_hdr : Int
  fc_plcf_atn_bkf : Int
  lcb_plcf_atn_bkf : Int
  fc_plcf_atn_bkl : Int
  lcb_plcf_atn_bkl : Int
  fc_pms : Int
  lcb_pms : Int
  fc_form_fld_sttbs : Int
  lcb_form_fld_sttbs : Int
  fc_plcfend_ref : Int
  lcb_plcfend_ref : Int
  fc_plcfend_txt : Int
  lcb_plcfend_txt : Int
  fc_plcf_fld_edn : Int
  lcb_plcf_fld_edn : Int
  fc_dgg_info : Int
  lcb_dgg_info : Int
  fc_sttbf_rmark : Int
  lcb_sttbf_rmark : Int
  fc_sttbf_caption : Int
  lcb_sttbf_caption : Int
  fc_sttbf_auto_caption : Int
  lcb_sttbf_auto_caption : Int
  fc_plcf_wkb : Int
  lcb_plcf_wkb : Int
  fc_plcf_spl : Int
  lcb_plcf_spl : Int
  fc_plcftxbx_txt : Int
  lcb_plcftxbx_txt : Int
  fc_plcf_fld_txbx : Int
  lcb_plcf_fld_txbx : Int
  fc_plcf_hdrtxbx_txt : Int
  lcb_plcf_hdrtxbx_txt : Int
  fc_plcffld_hdr_txbx : Int
  lcb_plcffld_hdr_txbx : Int
  fc_stw_user : Int
  lcb_stw_user : Int
  fc_sttb_ttmbd : Int
  lcb_sttb_ttmbd : Int
  fc_cookie_data : Int
  lcb_cookie_data : Int
  fc_pgd_mother_old_old : Int
  lcb_pgd_mother_old_old : Int
  fc_bkd_mother_old_old : Int
  lcb_bkd_mother_old_old : Int
  fc_pgd_ftn_old_old : Int
  lcb_pgd_ftn_old_old : Int
  fc_bkd_ftn_old_old : Int
  lcb_bkd_ftn_old_old : Int
  fc_pgd_edn_old_old : Int
  lcb_pgd_edn_old_old : Int
  fc_bkd_edn_old_old : Int
  lcb_bkd_edn_old_old : Int
  fc_sttbf_intl_fld : Int
  lcb_sttbf_intl_fld : Int
  fc_route_slip : Int
  lcb_route_slip : Int
  fc_sttb_saved_by : Int
  lcb_sttb_saved_by : Int
  fc_sttb_fnm : Int
  lcb_sttb_fnm : Int
  fc_plf_lst : Int
  lcb_plf_lst : Int
  fc_plf_lfo : Int
  lcb_plf_lfo : Int
  fc_plcf_txbx_bkd : Int
  lcb_plcf_txbx_bkd : Int
  fc_plcf_txbx_hdr_bkd : Int
  lcb_plcf_txbx_hdr_bkd : Int
  fc_doc_undo_word9 : Int
  lcb_doc_undo_word9 : Int
  fc_rgb_use : Int
  lcb_rgb_use : Int
  fc_usp : Int
  lcb_usp : Int
  fc_uskf : Int
  lcb_uskf : Int
  fc_plcupc_rgb_use : Int
  lcb_plcupc_rgb_use : Int
  fc_plcupc_usp : Int
  lcb_plcupc_usp : Int
  fc_sttb_glsy_style : Int
  lcb_sttb_glsy_style : Int
  fc_plgosl : Int
  lcb_plgosl : Int
  fc_plcocx : Int
  lcb_plcocx : Int
  fc_plcf_bte_lvc : Int
  lcb_plcf_bte_lvc : Int
  fc_dw_low_date_time : Int
  lcb_dw_low_date_time : Int
  fc_dw_high_date_time : Int
  lcb_dw_high_date_time : Int
  fc_plcf_lvc_pre10 : Int
  lcb_plcf_lvc_pre10 : Int
  fc_plcf_asumy : Int
  lcb_plcf_asumy : Int
  fc_plcf_gram : Int
  lcb_plcf_gram : Int
  fc_sttb_list_names : Int
  lcb_sttb_list_names : Int
  fc_sttbf_ussr : Int
  lcb_sttbf_ussr : Int
}

///|
/// FIB complete structure
pub struct FIB {
  base : FIBBase
  csw : Int
  cslw : Int
  cb_rg_fc_lcb : Int
  csw_new : Int
  n_fib_new : Int
  fib_rg_lw : FIBRgLw
  fib_rg_fc_lcb : FIBRgFcLcb
}

///|
/// FIB FC/LCB field names
fn fib_fc_lcb_name(index : Int) -> String {
  match index {
    0 => "StshfOrig"
    1 => "Stshf"
    2 => "PlcffndRef"
    3 => "PlcffndTxt"
    4 => "PlcfandRef"
    5 => "PlcfandTxt"
    6 => "PlcfSed"
    7 => "PlcPad"
    8 => "PlcfPhe"
    9 => "SttbfGlsy"
    10 => "PlcfGlsy"
    11 => "PlcfHdd"
    12 => "PlcfBteChpx"
    13 => "PlcfBtePapx"
    14 => "PlcfSea"
    15 => "SttbfFfn"
    16 => "PlcfFldMom"
    17 => "PlcfFldHdr"
    18 => "PlcfFldFtn"
    19 => "PlcfFldAtn"
    20 => "PlcfFldMcr"
    21 => "SttbfBkmk"
    22 => "PlcfBkf"
    23 => "PlcfBkl"
    24 => "Cmds"
    25 => "Unused1"
    26 => "SttbfMcr"
    27 => "PrDrvr"
    28 => "PrEnvPort"
    29 => "PrEnvLand"
    30 => "Wss"
    31 => "Dop"
    32 => "SttbfAssoc"
    33 => "Clx"
    34 => "PlcfPgdFtn"
    35 => "AutosaveSource"
    36 => "GrpXstAtnOwners"
    37 => "SttbfAtnBkmk"
    38 => "Unused2"
    39 => "Unused3"
    40 => "PlcSpaMom"
    41 => "PlcSpaHdr"
    42 => "PlcfAtnBkf"
    43 => "PlcfAtnBkl"
    44 => "Pms"
    45 => "FormFldSttbs"
    46 => "PlcfendRef"
    47 => "PlcfendTxt"
    48 => "PlcfFldEdn"
    49 => "Unused4"
    50 => "DggInfo"
    51 => "SttbfRMark"
    52 => "SttbfCaption"
    53 => "SttbfAutoCaption"
    54 => "PlcfWkb"
    55 => "PlcfSpl"
    56 => "PlcftxbxTxt"
    57 => "PlcfFldTxbx"
    58 => "PlcfHdrtxbxTxt"
    59 => "PlcffldHdrTxbx"
    60 => "StwUser"
    61 => "SttbTtmbd"
    62 => "CookieData"
    63 => "PgdMotherOldOld"
    64 => "BkdMotherOldOld"
    65 => "PgdFtnOldOld"
    66 => "BkdFtnOldOld"
    67 => "PgdEdnOldOld"
    68 => "BkdEdnOldOld"
    69 => "SttbfIntlFld"
    70 => "RouteSlip"
    71 => "SttbSavedBy"
    72 => "SttbFnm"
    73 => "PlfLst"
    74 => "PlfLfo"
    75 => "PlcfTxbxBkd"
    76 => "PlcfTxbxHdrBkd"
    77 => "DocUndoWord9"
    78 => "RgbUse"
    79 => "Usp"
    80 => "Uskf"
    81 => "PlcupcRgbUse"
    82 => "PlcupcUsp"
    83 => "SttbGlsyStyle"
    84 => "Plgosl"
    85 => "Plcocx"
    86 => "PlcfBteLvc"
    87 => "dwLowDateTime"
    88 => "dwHighDateTime"
    89 => "PlcfLvcPre10"
    90 => "PlcfAsumy"
    91 => "PlcfGram"
    92 => "SttbListNames"
    93 => "SttbfUssr"
    _ => "Field\{index}"
  }
}

///|
/// Parse FIB base header
fn parse_fib_base(reader : BinaryReader) -> FIBBase {
  let w_ident = reader.u16(0)
  let n_fib = reader.u16(2)
  let lid = reader.u16(6)
  let pn_next = reader.u16(8)
  let flags = reader.u16(10)
  let env_flags = reader.u16(18)
  FIBBase::{
    w_ident,
    n_fib,
    lid,
    pn_next,
    flags,
    env_flags,
    f_dot: (flags & 0x0001) != 0,
    f_glsy: (flags & 0x0002) != 0,
    f_complex: (flags & 0x0004) != 0,
    f_has_pic: (flags & 0x0008) != 0,
    c_quick_saves: (flags >> 4) & 0x0f,
    f_encrypted: (flags & 0x0100) != 0,
    f_which_tbl_stm: if (flags & 0x0200) != 0 {
      1
    } else {
      0
    },
    f_read_only_recommended: (flags & 0x0400) != 0,
    f_write_reservation: (flags & 0x0800) != 0,
    f_ext_char: (flags & 0x1000) != 0,
    f_load_override: (flags & 0x2000) != 0,
    f_far_east: (flags & 0x4000) != 0,
    f_obfuscated: (flags & 0x8000) != 0,
    n_fib_back: reader.u16(12),
    l_key: reader.u32(14),
    envr: reader.u8(18),
    f_mac: (env_flags & 0x0001) != 0,
    f_empty_special: (env_flags & 0x0002) != 0,
    f_load_override_page: (env_flags & 0x0004) != 0,
  }
}

///|
/// Parse FIB RgLw
fn parse_fib_rg_lw(bytes : ArrayView[Byte]) -> FIBRgLw {
  let reader = BinaryReader::from_view(bytes)
  let dwords = Array::new()
  let mut i = 0
  while i + 4 <= bytes.length() {
    dwords.push(reader.i32(i))
    i += 4
  }
  FIBRgLw::{
    raw: dwords,
    cb_mac: if dwords.length() > 0 {
      dwords[0]
    } else {
      0
    },
    ccp_text: if dwords.length() > 3 {
      dwords[3]
    } else {
      0
    },
    ccp_ftn: if dwords.length() > 4 {
      dwords[4]
    } else {
      0
    },
    ccp_hdd: if dwords.length() > 5 {
      dwords[5]
    } else {
      0
    },
    ccp_mcr: if dwords.length() > 6 {
      dwords[6]
    } else {
      0
    },
    ccp_atn: if dwords.length() > 7 {
      dwords[7]
    } else {
      0
    },
    ccp_edn: if dwords.length() > 8 {
      dwords[8]
    } else {
      0
    },
    ccp_txbx: if dwords.length() > 9 {
      dwords[9]
    } else {
      0
    },
    ccp_hdr_txbx: if dwords.length() > 10 {
      dwords[10]
    } else {
      0
    },
  }
}

///|
/// Parse FIB RgFcLcb
fn parse_fib_rg_fc_lcb(bytes : ArrayView[Byte], count : Int) -> FIBRgFcLcb {
  let reader = BinaryReader::from_view(bytes)
  let pairs = Array::new()
  let mut i = 0
  while i < count && i * 8 + 8 <= bytes.length() {
    let fc = reader.u32(i * 8)
    let lcb = reader.u32(i * 8 + 4)
    let name = fib_fc_lcb_name(i)
    pairs.push(FcLcbPair::{ name, fc, lcb, index: i })
    i += 1
  }

  // Helper to get fc/lcb by index
  fn get_fc_lcb(pairs : Array[FcLcbPair], index : Int) -> (Int, Int) {
    if index < pairs.length() {
      (pairs[index].fc, pairs[index].lcb)
    } else {
      (0, 0)
    }
  }

  let (fc_stshf_orig, lcb_stshf_orig) = get_fc_lcb(pairs, 0)
  let (fc_stshf, lcb_stshf) = get_fc_lcb(pairs, 1)
  let (fc_plcffnd_ref, lcb_plcffnd_ref) = get_fc_lcb(pairs, 2)
  let (fc_plcffnd_txt, lcb_plcffnd_txt) = get_fc_lcb(pairs, 3)
  let (fc_plcfand_ref, lcb_plcfand_ref) = get_fc_lcb(pairs, 4)
  let (fc_plcfand_txt, lcb_plcfand_txt) = get_fc_lcb(pairs, 5)
  let (fc_plcf_sed, lcb_plcf_sed) = get_fc_lcb(pairs, 6)
  let (fc_plc_pad, lcb_plc_pad) = get_fc_lcb(pairs, 7)
  let (fc_plcf_phe, lcb_plcf_phe) = get_fc_lcb(pairs, 8)
  let (fc_sttbf_glsy, lcb_sttbf_glsy) = get_fc_lcb(pairs, 9)
  let (fc_plcf_glsy, lcb_plcf_glsy) = get_fc_lcb(pairs, 10)
  let (fc_plcf_hdd, lcb_plcf_hdd) = get_fc_lcb(pairs, 11)
  let (fc_plcf_bte_chpx, lcb_plcf_bte_chpx) = get_fc_lcb(pairs, 12)
  let (fc_plcf_bte_papx, lcb_plcf_bte_papx) = get_fc_lcb(pairs, 13)
  let (fc_plcf_sea, lcb_plcf_sea) = get_fc_lcb(pairs, 14)
  let (fc_sttbf_ffn, lcb_sttbf_ffn) = get_fc_lcb(pairs, 15)
  let (fc_plcf_fld_mom, lcb_plcf_fld_mom) = get_fc_lcb(pairs, 16)
  let (fc_plcf_fld_hdr, lcb_plcf_fld_hdr) = get_fc_lcb(pairs, 17)
  let (fc_plcf_fld_ftn, lcb_plcf_fld_ftn) = get_fc_lcb(pairs, 18)
  let (fc_plcf_fld_atn, lcb_plcf_fld_atn) = get_fc_lcb(pairs, 19)
  let (fc_plcf_fld_mcr, lcb_plcf_fld_mcr) = get_fc_lcb(pairs, 20)
  let (fc_sttbf_bkmk, lcb_sttbf_bkmk) = get_fc_lcb(pairs, 21)
  let (fc_plcf_bkf, lcb_plcf_bkf) = get_fc_lcb(pairs, 22)
  let (fc_plcf_bkl, lcb_plcf_bkl) = get_fc_lcb(pairs, 23)
  let (fc_cmds, lcb_cmds) = get_fc_lcb(pairs, 24)
  let (fc_sttbf_mcr, lcb_sttbf_mcr) = get_fc_lcb(pairs, 26)
  let (fc_pr_drvr, lcb_pr_drvr) = get_fc_lcb(pairs, 27)
  let (fc_pr_env_port, lcb_pr_env_port) = get_fc_lcb(pairs, 28)
  let (fc_pr_env_land, lcb_pr_env_land) = get_fc_lcb(pairs, 29)
  let (fc_wss, lcb_wss) = get_fc_lcb(pairs, 30)
  let (fc_dop, lcb_dop) = get_fc_lcb(pairs, 31)
  let (fc_sttbf_assoc, lcb_sttbf_assoc) = get_fc_lcb(pairs, 32)
  let (fc_clx, lcb_clx) = get_fc_lcb(pairs, 33)
  let (fc_plcf_pgd_ftn, lcb_plcf_pgd_ftn) = get_fc_lcb(pairs, 34)
  let (fc_autosave_source, lcb_autosave_source) = get_fc_lcb(pairs, 35)
  let (fc_grp_xst_atn_owners, lcb_grp_xst_atn_owners) = get_fc_lcb(pairs, 36)
  let (fc_sttbf_atn_bkmk, lcb_sttbf_atn_bkmk) = get_fc_lcb(pairs, 37)
  let (fc_plcf_spa_mom, lcb_plcf_spa_mom) = get_fc_lcb(pairs, 40)
  let (fc_plcf_spa_hdr, lcb_plcf_spa_hdr) = get_fc_lcb(pairs, 41)
  let (fc_plcf_atn_bkf, lcb_plcf_atn_bkf) = get_fc_lcb(pairs, 42)
  let (fc_plcf_atn_bkl, lcb_plcf_atn_bkl) = get_fc_lcb(pairs, 43)
  let (fc_pms, lcb_pms) = get_fc_lcb(pairs, 44)
  let (fc_form_fld_sttbs, lcb_form_fld_sttbs) = get_fc_lcb(pairs, 45)
  let (fc_plcfend_ref, lcb_plcfend_ref) = get_fc_lcb(pairs, 46)
  let (fc_plcfend_txt, lcb_plcfend_txt) = get_fc_lcb(pairs, 47)
  let (fc_plcf_fld_edn, lcb_plcf_fld_edn) = get_fc_lcb(pairs, 48)
  let (fc_dgg_info, lcb_dgg_info) = get_fc_lcb(pairs, 50)
  let (fc_sttbf_rmark, lcb_sttbf_rmark) = get_fc_lcb(pairs, 51)
  let (fc_sttbf_caption, lcb_sttbf_caption) = get_fc_lcb(pairs, 52)
  let (fc_sttbf_auto_caption, lcb_sttbf_auto_caption) = get_fc_lcb(pairs, 53)
  let (fc_plcf_wkb, lcb_plcf_wkb) = get_fc_lcb(pairs, 54)
  let (fc_plcf_spl, lcb_plcf_spl) = get_fc_lcb(pairs, 55)
  let (fc_plcftxbx_txt, lcb_plcftxbx_txt) = get_fc_lcb(pairs, 56)
  let (fc_plcf_fld_txbx, lcb_plcf_fld_txbx) = get_fc_lcb(pairs, 57)
  let (fc_plcf_hdrtxbx_txt, lcb_plcf_hdrtxbx_txt) = get_fc_lcb(pairs, 58)
  let (fc_plcffld_hdr_txbx, lcb_plcffld_hdr_txbx) = get_fc_lcb(pairs, 59)
  let (fc_stw_user, lcb_stw_user) = get_fc_lcb(pairs, 60)
  let (fc_sttb_ttmbd, lcb_sttb_ttmbd) = get_fc_lcb(pairs, 61)
  let (fc_cookie_data, lcb_cookie_data) = get_fc_lcb(pairs, 62)
  let (fc_pgd_mother_old_old, lcb_pgd_mother_old_old) = get_fc_lcb(pairs, 63)
  let (fc_bkd_mother_old_old, lcb_bkd_mother_old_old) = get_fc_lcb(pairs, 64)
  let (fc_pgd_ftn_old_old, lcb_pgd_ftn_old_old) = get_fc_lcb(pairs, 65)
  let (fc_bkd_ftn_old_old, lcb_bkd_ftn_old_old) = get_fc_lcb(pairs, 66)
  let (fc_pgd_edn_old_old, lcb_pgd_edn_old_old) = get_fc_lcb(pairs, 67)
  let (fc_bkd_edn_old_old, lcb_bkd_edn_old_old) = get_fc_lcb(pairs, 68)
  let (fc_sttbf_intl_fld, lcb_sttbf_intl_fld) = get_fc_lcb(pairs, 69)
  let (fc_route_slip, lcb_route_slip) = get_fc_lcb(pairs, 70)
  let (fc_sttb_saved_by, lcb_sttb_saved_by) = get_fc_lcb(pairs, 71)
  let (fc_sttb_fnm, lcb_sttb_fnm) = get_fc_lcb(pairs, 72)
  let (fc_plf_lst, lcb_plf_lst) = get_fc_lcb(pairs, 73)
  let (fc_plf_lfo, lcb_plf_lfo) = get_fc_lcb(pairs, 74)
  let (fc_plcf_txbx_bkd, lcb_plcf_txbx_bkd) = get_fc_lcb(pairs, 75)
  let (fc_plcf_txbx_hdr_bkd, lcb_plcf_txbx_hdr_bkd) = get_fc_lcb(pairs, 76)
  let (fc_doc_undo_word9, lcb_doc_undo_word9) = get_fc_lcb(pairs, 77)
  let (fc_rgb_use, lcb_rgb_use) = get_fc_lcb(pairs, 78)
  let (fc_usp, lcb_usp) = get_fc_lcb(pairs, 79)
  let (fc_uskf, lcb_uskf) = get_fc_lcb(pairs, 80)
  let (fc_plcupc_rgb_use, lcb_plcupc_rgb_use) = get_fc_lcb(pairs, 81)
  let (fc_plcupc_usp, lcb_plcupc_usp) = get_fc_lcb(pairs, 82)
  let (fc_sttb_glsy_style, lcb_sttb_glsy_style) = get_fc_lcb(pairs, 83)
  let (fc_plgosl, lcb_plgosl) = get_fc_lcb(pairs, 84)
  let (fc_plcocx, lcb_plcocx) = get_fc_lcb(pairs, 85)
  let (fc_plcf_bte_lvc, lcb_plcf_bte_lvc) = get_fc_lcb(pairs, 86)
  let (fc_dw_low_date_time, lcb_dw_low_date_time) = get_fc_lcb(pairs, 87)
  let (fc_dw_high_date_time, lcb_dw_high_date_time) = get_fc_lcb(pairs, 88)
  let (fc_plcf_lvc_pre10, lcb_plcf_lvc_pre10) = get_fc_lcb(pairs, 89)
  let (fc_plcf_asumy, lcb_plcf_asumy) = get_fc_lcb(pairs, 90)
  let (fc_plcf_gram, lcb_plcf_gram) = get_fc_lcb(pairs, 91)
  let (fc_sttb_list_names, lcb_sttb_list_names) = get_fc_lcb(pairs, 92)
  let (fc_sttbf_ussr, lcb_sttbf_ussr) = get_fc_lcb(pairs, 93)

  FIBRgFcLcb::{
    pairs,
    fc_stshf_orig,
    lcb_stshf_orig,
    fc_stshf,
    lcb_stshf,
    fc_plcffnd_ref,
    lcb_plcffnd_ref,
    fc_plcffnd_txt,
    lcb_plcffnd_txt,
    fc_plcfand_ref,
    lcb_plcfand_ref,
    fc_plcfand_txt,
    lcb_plcfand_txt,
    fc_plcf_sed,
    lcb_plcf_sed,
    fc_plc_pad,
    lcb_plc_pad,
    fc_plcf_phe,
    lcb_plcf_phe,
    fc_sttbf_glsy,
    lcb_sttbf_glsy,
    fc_plcf_glsy,
    lcb_plcf_glsy,
    fc_plcf_hdd,
    lcb_plcf_hdd,
    fc_plcf_bte_chpx,
    lcb_plcf_bte_chpx,
    fc_plcf_bte_papx,
    lcb_plcf_bte_papx,
    fc_plcf_sea,
    lcb_plcf_sea,
    fc_sttbf_ffn,
    lcb_sttbf_ffn,
    fc_plcf_fld_mom,
    lcb_plcf_fld_mom,
    fc_plcf_fld_hdr,
    lcb_plcf_fld_hdr,
    fc_plcf_fld_ftn,
    lcb_plcf_fld_ftn,
    fc_plcf_fld_atn,
    lcb_plcf_fld_atn,
    fc_plcf_fld_mcr,
    lcb_plcf_fld_mcr,
    fc_sttbf_bkmk,
    lcb_sttbf_bkmk,
    fc_plcf_bkf,
    lcb_plcf_bkf,
    fc_plcf_bkl,
    lcb_plcf_bkl,
    fc_cmds,
    lcb_cmds,
    fc_sttbf_mcr,
    lcb_sttbf_mcr,
    fc_pr_drvr,
    lcb_pr_drvr,
    fc_pr_env_port,
    lcb_pr_env_port,
    fc_pr_env_land,
    lcb_pr_env_land,
    fc_wss,
    lcb_wss,
    fc_dop,
    lcb_dop,
    fc_sttbf_assoc,
    lcb_sttbf_assoc,
    fc_clx,
    lcb_clx,
    fc_plcf_pgd_ftn,
    lcb_plcf_pgd_ftn,
    fc_autosave_source,
    lcb_autosave_source,
    fc_grp_xst_atn_owners,
    lcb_grp_xst_atn_owners,
    fc_sttbf_atn_bkmk,
    lcb_sttbf_atn_bkmk,
    fc_plcf_spa_mom,
    lcb_plcf_spa_mom,
    fc_plcf_spa_hdr,
    lcb_plcf_spa_hdr,
    fc_plcf_atn_bkf,
    lcb_plcf_atn_bkf,
    fc_plcf_atn_bkl,
    lcb_plcf_atn_bkl,
    fc_pms,
    lcb_pms,
    fc_form_fld_sttbs,
    lcb_form_fld_sttbs,
    fc_plcfend_ref,
    lcb_plcfend_ref,
    fc_plcfend_txt,
    lcb_plcfend_txt,
    fc_plcf_fld_edn,
    lcb_plcf_fld_edn,
    fc_dgg_info,
    lcb_dgg_info,
    fc_sttbf_rmark,
    lcb_sttbf_rmark,
    fc_sttbf_caption,
    lcb_sttbf_caption,
    fc_sttbf_auto_caption,
    lcb_sttbf_auto_caption,
    fc_plcf_wkb,
    lcb_plcf_wkb,
    fc_plcf_spl,
    lcb_plcf_spl,
    fc_plcftxbx_txt,
    lcb_plcftxbx_txt,
    fc_plcf_fld_txbx,
    lcb_plcf_fld_txbx,
    fc_plcf_hdrtxbx_txt,
    lcb_plcf_hdrtxbx_txt,
    fc_plcffld_hdr_txbx,
    lcb_plcffld_hdr_txbx,
    fc_stw_user,
    lcb_stw_user,
    fc_sttb_ttmbd,
    lcb_sttb_ttmbd,
    fc_cookie_data,
    lcb_cookie_data,
    fc_pgd_mother_old_old,
    lcb_pgd_mother_old_old,
    fc_bkd_mother_old_old,
    lcb_bkd_mother_old_old,
    fc_pgd_ftn_old_old,
    lcb_pgd_ftn_old_old,
    fc_bkd_ftn_old_old,
    lcb_bkd_ftn_old_old,
    fc_pgd_edn_old_old,
    lcb_pgd_edn_old_old,
    fc_bkd_edn_old_old,
    lcb_bkd_edn_old_old,
    fc_sttbf_intl_fld,
    lcb_sttbf_intl_fld,
    fc_route_slip,
    lcb_route_slip,
    fc_sttb_saved_by,
    lcb_sttb_saved_by,
    fc_sttb_fnm,
    lcb_sttb_fnm,
    fc_plf_lst,
    lcb_plf_lst,
    fc_plf_lfo,
    lcb_plf_lfo,
    fc_plcf_txbx_bkd,
    lcb_plcf_txbx_bkd,
    fc_plcf_txbx_hdr_bkd,
    lcb_plcf_txbx_hdr_bkd,
    fc_doc_undo_word9,
    lcb_doc_undo_word9,
    fc_rgb_use,
    lcb_rgb_use,
    fc_usp,
    lcb_usp,
    fc_uskf,
    lcb_uskf,
    fc_plcupc_rgb_use,
    lcb_plcupc_rgb_use,
    fc_plcupc_usp,
    lcb_plcupc_usp,
    fc_sttb_glsy_style,
    lcb_sttb_glsy_style,
    fc_plgosl,
    lcb_plgosl,
    fc_plcocx,
    lcb_plcocx,
    fc_plcf_bte_lvc,
    lcb_plcf_bte_lvc,
    fc_dw_low_date_time,
    lcb_dw_low_date_time,
    fc_dw_high_date_time,
    lcb_dw_high_date_time,
    fc_plcf_lvc_pre10,
    lcb_plcf_lvc_pre10,
    fc_plcf_asumy,
    lcb_plcf_asumy,
    fc_plcf_gram,
    lcb_plcf_gram,
    fc_sttb_list_names,
    lcb_sttb_list_names,
    fc_sttbf_ussr,
    lcb_sttbf_ussr,
  }
}

///|
/// Parse FIB from WordDocument stream
pub fn parse_fib(word_bytes : FixedArray[Byte]) -> FIB {
  let reader = BinaryReader::make(word_bytes)
  let base = parse_fib_base(reader)

  let mut offset = 32
  let csw = reader.u16(offset)
  offset += 2
  let _fib_rg_w_bytes = reader.slice(offset, csw * 2)
  offset += csw * 2

  let cslw = reader.u16(offset)
  offset += 2
  let _fib_rg_lw_bytes = reader.slice(offset, cslw * 4)
  offset += cslw * 4

  let cb_rg_fc_lcb = reader.u16(offset)
  offset += 2
  let _fib_rg_fc_lcb_bytes = reader.slice(offset, cb_rg_fc_lcb * 8)
  offset += cb_rg_fc_lcb * 8

  let csw_new = if reader.ensure(offset, 2) { reader.u16(offset) } else { 0 }
  if reader.ensure(offset, 2) {
    offset += 2
  }
  let _fib_rg_csw_new_bytes = if csw_new > 0 {
    reader.slice(offset, csw_new * 2)
  } else {
    FixedArray::make(0, b'\x00')
  }

  let fib_rg_lw = parse_fib_rg_lw(_fib_rg_lw_bytes)
  let fib_rg_fc_lcb = parse_fib_rg_fc_lcb(_fib_rg_fc_lcb_bytes, cb_rg_fc_lcb)
  let n_fib_new = if csw_new > 0 {
    BinaryReader::from_view(_fib_rg_csw_new_bytes).u16(0)
  } else {
    0
  }

  FIB::{
    base,
    csw,
    cslw,
    cb_rg_fc_lcb,
    csw_new,
    n_fib_new,
    fib_rg_lw,
    fib_rg_fc_lcb,
  }
}
