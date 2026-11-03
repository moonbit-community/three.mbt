// Upstream examples/jsm/libs/fflate.module.js (fflate 0.8.3): the zlib inflate path
// behind `unzlibSync` (`zls`, `inflt`, `hMap` and their tables). Data stays in JS
// typed arrays, so out-of-range reads give `undefined` as upstream (read through
// `get_int`, which is `a[ i ] | 0`; every such read feeds a bitwise operation upstream).

///|
/// `new Uint8Array( init )` etc., as fflate's aliases `u8`, `u16`, `i32`.
fn fflate_u8(n : Int32) -> @core.TypedArray {
  @core.TypedArray::uint8(n)
}

///|
fn fflate_u16(n : Int32) -> @core.TypedArray {
  @core.TypedArray::uint16(n)
}

///|
/// Fixed length extra bits.
let fflate_fleb : @core.TypedArray = @core.TypedArray::uint8([
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0, 0, 0, 0,
])

///|
/// Fixed distance extra bits.
let fflate_fdeb : @core.TypedArray = @core.TypedArray::uint8([
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13, 0, 0,
])

///|
/// Code length index map.
let fflate_clim : @core.TypedArray = @core.TypedArray::uint8([
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
])

///|
/// Get base, reverse index map from extra bits.
fn fflate_freb(
  eb : @core.TypedArray,
  start : Int32,
) -> (@core.TypedArray, @core.TypedArray) {
  let mut start = start
  let b = fflate_u16(31)
  for i in 0..<31 {
    // `eb[ -1 ]` is `undefined`, and `1 << undefined` is 1
    start += 1 << eb.get_int(i - 1)
    b[i] = start.to_double()
  }
  // numbers here are at max 18 bits
  let r = @core.TypedArray::int32(b.get_int(30))
  for i in 1..<30 {
    for j in b.get_int(i)..<b.get_int(i + 1) {
      r[j] = (((j - b.get_int(i)) << 5) | i).to_double()
    }
  }
  (b, r)
}

///|
let fflate_fl_revfl : (@core.TypedArray, @core.TypedArray) = {
  let (fl, revfl) = fflate_freb(fflate_fleb, 2)
  // we can ignore the fact that the other numbers are wrong; they never happen anyway
  fl[28] = 258
  revfl[258] = 28
  (fl, revfl)
}

///|
let fflate_fl : @core.TypedArray = fflate_fl_revfl.0

///|
let fflate_fd : @core.TypedArray = fflate_freb(fflate_fdeb, 0).0

///|
/// Map of value to reverse (assuming 16 bits).
let fflate_rev : @core.TypedArray = {
  let rev = fflate_u16(32768)
  for i in 0..<32768 {
    // reverse table algorithm from SO
    let mut x = ((i & 0xAAAA) >> 1) | ((i & 0x5555) << 1)
    x = ((x & 0xCCCC) >> 2) | ((x & 0x3333) << 2)
    x = ((x & 0xF0F0) >> 4) | ((x & 0x0F0F) << 4)
    rev[i] = ((((x & 0xFF00) >> 8) | ((x & 0x00FF) << 8)) >> 1).to_double()
  }
  rev
}

///|
/// Create huffman tree from u8 "map": index -> code length for code index.
/// `mb` (max bits) must be at most 15.
fn fflate_h_map(
  cd : @core.TypedArray,
  mb : Int32,
  r : Bool,
) -> @core.TypedArray {
  let s = cd.length()
  // u16 "map": index -> # of codes with bit length = index
  let l = fflate_u16(mb)
  // length of cd must be 288 (total # of codes)
  for i in 0..<s {
    if cd.get_int(i) != 0 {
      let k = cd.get_int(i) - 1
      l[k] = l[k] + 1.0
    }
  }
  // u16 "map": index -> minimum code for bit length = index
  let le = fflate_u16(mb)
  for i in 1..<mb {
    le[i] = ((le.get_int(i - 1) + l.get_int(i - 1)) << 1).to_double()
  }
  let co = if r {
    // u16 "map": index -> number of actual bits, symbol for code
    let co = fflate_u16(1 << mb)
    // bits to remove for reverser
    let rvb = 15 - mb
    for i in 0..<s {
      // ignore 0 lengths
      let cdi = cd.get_int(i)
      if cdi != 0 {
        // num encoding both symbol and bits read
        let sv = (i << 4) | cdi
        // free bits
        let r_1 = mb - cdi
        // start value
        let lv = le.get_int(cdi - 1)
        le[cdi - 1] = (lv + 1).to_double()
        let mut v = lv << r_1
        // m is end value
        let m = v | ((1 << r_1) - 1)
        while v <= m {
          // every 16 bit value starting with the code yields the same result
          co[fflate_rev.get_int(v) >> rvb] = sv.to_double()
          v += 1
        }
      }
    }
    co
  } else {
    let co = fflate_u16(s)
    for i in 0..<s {
      let cdi = cd.get_int(i)
      if cdi != 0 {
        let lv = le.get_int(cdi - 1)
        le[cdi - 1] = (lv + 1).to_double()
        co[i] = (fflate_rev.get_int(lv) >> (15 - cdi)).to_double()
      }
    }
    co
  }
  co
}

///|
/// Fixed length tree.
let fflate_flt : @core.TypedArray = {
  let flt = fflate_u8(288)
  for i in 0..<144 {
    flt[i] = 8
  }
  for i in 144..<256 {
    flt[i] = 9
  }
  for i in 256..<280 {
    flt[i] = 7
  }
  for i in 280..<288 {
    flt[i] = 8
  }
  flt
}

///|
/// Fixed distance tree.
let fflate_fdt : @core.TypedArray = {
  let fdt = fflate_u8(32)
  for i in 0..<32 {
    fdt[i] = 5
  }
  fdt
}

///|
/// Fixed length map.
let fflate_flrm : @core.TypedArray = fflate_h_map(fflate_flt, 9, true)

///|
/// Fixed distance map.
let fflate_fdrm : @core.TypedArray = fflate_h_map(fflate_fdt, 5, true)

///|
/// Find max of array.
fn fflate_max(a : @core.TypedArray) -> Int32 {
  let mut m = a.get_int(0)
  for i in 1..<a.length() {
    if a.get_int(i) > m {
      m = a.get_int(i)
    }
  }
  m
}

///|
/// Read d, starting at bit p and mask with m.
fn fflate_bits(d : @core.TypedArray, p : Int32, m : Int32) -> Int32 {
  let o = p / 8
  ((d.get_int(o) | (d.get_int(o + 1) << 8)) >> (p & 7)) & m
}

///|
/// Read d, starting at bit p continuing for at least 16 bits.
fn fflate_bits16(d : @core.TypedArray, p : Int32) -> Int32 {
  let o = p / 8
  (d.get_int(o) | (d.get_int(o + 1) << 8) | (d.get_int(o + 2) << 16)) >> (p & 7)
}

///|
/// Get end of byte.
fn fflate_shft(p : Int32) -> Int32 {
  (p + 7) / 8
}

///|
/// Typed array slice, as `slc( v, s, e )`.
fn fflate_slc(v : @core.TypedArray, s : Int32, e : Int32) -> @core.TypedArray {
  let s = if s < 0 { 0 } else { s }
  let e = if e > v.length() { v.length() } else { e }
  @core.TypedArray::uint8(v.subarray(start=s, end=e))
}

///|
/// Error messages, indexed by `FlateErrorCode`.
let fflate_ec : Array[String?] = [
  Some("unexpected EOF"),
  Some("invalid block type"),
  Some("invalid length/literal"),
  Some("invalid distance"),
  Some("stream finished"),
  Some("no stream handler"),
  None, // determined by compression function
  Some("no callback"),
  Some("invalid UTF-8 data"),
  Some("extra field too long"),
  Some("date not in range 1980-2099"),
  Some("filename too long"),
  Some("stream finishing"),
  Some("invalid zip data"),
]

///|
extern "js" fn fflate_throw_error(
  message : @core.JsValue,
  code : Int32,
) -> Unit =
  #|(msg, ind) => {
  #|  var e = new Error(msg);
  #|  e.code = ind;
  #|  throw e;
  #|}

///|
/// Upstream `err( ind, msg )`: throws an `Error` whose `code` is `ind`.
fn fflate_err(ind : Int32, msg? : String) -> Unit {
  let message = match msg {
    Some(msg) if msg != "" => @core.JsValue::of(msg)
    _ =>
      match fflate_ec.get(ind) {
        Some(Some(m)) => @core.JsValue::of(m)
        _ => @core.JsValue::undefined()
      }
  }
  fflate_throw_error(message, ind)
}

///|
/// Inflate state (`st`): `i` mode, `f` final, `p` bit position, `b` byte count,
/// `l`/`d` length and distance maps, `m`/`n` their bit counts.
priv struct FflateInflateState {
  i : Int32
  mut f : Int32
  mut p : Int32
  mut b : Int32
  mut l : @core.TypedArray?
  mut d : @core.TypedArray?
  mut m : Int32
  mut n : Int32
}

///|
/// Expands raw DEFLATE data.
fn fflate_inflt(
  dat : @core.TypedArray,
  st : FflateInflateState,
  buf : @core.TypedArray?,
  dict : @core.TypedArray?,
) -> @core.TypedArray {
  // source length       dict length
  let sl = dat.length()
  let dl = match dict {
    Some(dict) => dict.length()
    None => 0
  }
  if sl == 0 || (st.f != 0 && st.l is None) {
    return match buf {
      Some(buf) => buf
      None => fflate_u8(0)
    }
  }
  let no_buf = buf is None
  // have to estimate size
  let resize = no_buf || st.i != 2
  // no state
  let no_st = st.i != 0
  // Assumes roughly 33% compression ratio average
  let mut buf = match buf {
    Some(buf) => buf
    None => fflate_u8(sl * 3)
  }
  // ensure buffer can fit at least l elements
  fn cbuf(l : Int32) {
    let bl = buf.length()
    // need to increase size to fit
    if l > bl {
      // Double or set to necessary, whichever is greater
      let nbuf = fflate_u8(if bl * 2 > l { bl * 2 } else { l })
      nbuf.set_from(buf)
      buf = nbuf
    }
  }
  //  last chunk         bitpos           bytes
  let mut final_ = st.f
  let mut pos = st.p
  let mut bt = st.b
  let mut lm = st.l
  let mut dm = st.d
  let mut lbt = st.m
  let mut dbt = st.n
  // total bits
  let tbts = sl * 8
  while true {
    if lm is None {
      // BFINAL - this is only 1 when last chunk is next
      final_ = fflate_bits(dat, pos, 1)
      // type: 0 = no compression, 1 = fixed huffman, 2 = dynamic huffman
      let type_ = fflate_bits(dat, pos + 1, 3)
      pos += 3
      if type_ == 0 {
        // go to end of byte boundary
        let s = fflate_shft(pos) + 4
        let l = dat.get_int(s - 4) | (dat.get_int(s - 3) << 8)
        let t = s + l
        if t > sl {
          if no_st {
            fflate_err(0)
          }
          break
        }
        // ensure size
        if resize {
          cbuf(bt + l)
        }
        // Copy over uncompressed data
        buf.set_from(dat.subarray(start=s, end=t), offset=bt)
        // Get new bitpos, update byte count
        bt += l
        st.b = bt
        pos = t * 8
        st.p = pos
        st.f = final_
        if final_ != 0 {
          break
        }
        continue
      } else if type_ == 1 {
        lm = Some(fflate_flrm)
        dm = Some(fflate_fdrm)
        lbt = 9
        dbt = 5
      } else if type_ == 2 {
        //  literal                            lengths
        let h_lit = fflate_bits(dat, pos, 31) + 257
        let hc_len = fflate_bits(dat, pos + 10, 15) + 4
        let tl = h_lit + fflate_bits(dat, pos + 5, 31) + 1
        pos += 14
        // length+distance tree
        let ldt = fflate_u8(tl)
        // code length tree
        let clt = fflate_u8(19)
        for i in 0..<hc_len {
          // use index map to get real code
          clt[fflate_clim.get_int(i)] = fflate_bits(dat, pos + i * 3, 7).to_double()
        }
        pos += hc_len * 3
        // code lengths bits
        let clb = fflate_max(clt)
        let clbmsk = (1 << clb) - 1
        // code lengths map
        let clm = fflate_h_map(clt, clb, true)
        let mut i = 0
        while i < tl {
          let r = clm.get_int(fflate_bits(dat, pos, clbmsk))
          // bits read
          pos += r & 15
          // symbol
          let s = r >> 4
          // code length to copy
          if s < 16 {
            ldt[i] = s.to_double()
            i += 1
          } else {
            //  copy   count
            let mut c = 0
            let mut n = 0
            if s == 16 {
              n = 3 + fflate_bits(dat, pos, 3)
              pos += 2
              c = ldt.get_int(i - 1)
            } else if s == 17 {
              n = 3 + fflate_bits(dat, pos, 7)
              pos += 3
            } else if s == 18 {
              n = 11 + fflate_bits(dat, pos, 127)
              pos += 7
            }
            while n != 0 {
              n -= 1
              ldt[i] = c.to_double()
              i += 1
            }
          }
        }
        //    length tree                 distance tree
        let lt = ldt.subarray(start=0, end=h_lit)
        let dt = ldt.subarray(start=h_lit)
        // max length bits
        lbt = fflate_max(lt)
        // max dist bits
        dbt = fflate_max(dt)
        lm = Some(fflate_h_map(lt, lbt, true))
        dm = Some(fflate_h_map(dt, dbt, true))
      } else {
        fflate_err(1)
      }
      if pos > tbts {
        if no_st {
          fflate_err(0)
        }
        break
      }
    }
    // Make sure the buffer can hold this + the largest possible addition
    // Maximum chunk size (practically, theoretically infinite) is 2^17
    if resize {
      cbuf(bt + 131072)
    }
    let lms = (1 << lbt) - 1
    let dms = (1 << dbt) - 1
    let mut lpos = pos
    let lmap = lm.unwrap()
    let dmap = dm.unwrap()
    while true {
      // bits read, code
      let c = lmap.get_int(fflate_bits16(dat, pos) & lms)
      let sym = c >> 4
      pos += c & 15
      if pos > tbts {
        if no_st {
          fflate_err(0)
        }
        break
      }
      if c == 0 {
        fflate_err(2)
      }
      if sym < 256 {
        buf[bt] = sym.to_double()
        bt += 1
      } else if sym == 256 {
        lpos = pos
        lm = None
        break
      } else {
        let mut add = sym - 254
        // no extra bits needed if less
        if sym > 264 {
          // index
          let i = sym - 257
          let b = fflate_fleb.get_int(i)
          add = fflate_bits(dat, pos, (1 << b) - 1) + fflate_fl.get_int(i)
          pos += b
        }
        // dist
        let d = dmap.get_int(fflate_bits16(dat, pos) & dms)
        let dsym = d >> 4
        if d == 0 {
          fflate_err(3)
        }
        pos += d & 15
        let mut dt = fflate_fd.get_int(dsym)
        if dsym > 3 {
          let b = fflate_fdeb.get_int(dsym)
          dt += fflate_bits16(dat, pos) & ((1 << b) - 1)
          pos += b
        }
        if pos > tbts {
          if no_st {
            fflate_err(0)
          }
          break
        }
        if resize {
          cbuf(bt + 131072)
        }
        let end = bt + add
        if bt < dt {
          let shift = dl - dt
          let dend = if dt < end { dt } else { end }
          if shift + bt < 0 {
            fflate_err(3)
          }
          let dict = dict.unwrap()
          while bt < dend {
            buf[bt] = dict.get(shift + bt)
            bt += 1
          }
        }
        while bt < end {
          buf[bt] = buf.get(bt - dt)
          bt += 1
        }
      }
      lpos = pos
    }
    st.l = lm
    st.p = lpos
    st.b = bt
    st.f = final_
    if lm is Some(_) {
      final_ = 1
      st.m = lbt
      st.d = dm
      st.n = dbt
    }
    if final_ != 0 {
      break
    }
  }
  // don't reallocate for streams or user buffers
  if bt != buf.length() && no_buf {
    fflate_slc(buf, 0, bt)
  } else {
    buf.subarray(start=0, end=bt)
  }
}

///|
/// zlib start: validates the header and returns its length.
fn fflate_zls(d : @core.TypedArray, dict : Bool) -> Int32 {
  if (d.get_int(0) & 15) != 8 ||
    d.get_int(0) >> 4 > 7 ||
    ((d.get_int(0) << 8) | d.get_int(1)) % 31 != 0 {
    fflate_err(6, msg="invalid zlib data")
  }
  if ((d.get_int(1) >> 5) & 1) == (if dict { 0 } else { 1 }) {
    fflate_err(
      6,
      msg="invalid zlib data: " +
        (if (d.get_int(1) & 32) != 0 { "need" } else { "unexpected" }) +
        " dictionary",
    )
  }
  ((d.get_int(1) >> 3) & 4) + 2
}

///|
/// Expands zlib data synchronously (`unzlibSync( data, { out, dictionary } )`).
/// Errors are thrown as upstream's, a JS `Error` with a `code`.
pub fn unzlib_sync(
  data : @core.TypedArray,
  out? : @core.TypedArray,
  dictionary? : @core.TypedArray,
) -> @core.TypedArray {
  fflate_inflt(
    data.subarray(start=fflate_zls(data, dictionary is Some(_)), end=-4),
    { i: 2, f: 0, p: 0, b: 0, l: None, d: None, m: 0, n: 0, },
    out,
    dictionary,
  )
}
