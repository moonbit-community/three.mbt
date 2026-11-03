// Upstream src/audio/AudioAnalyser.js.

///|
/// Frequency analysis of an `Audio`'s output.
pub(all) struct AudioAnalyser {
  analyser : AnalyserNode
  /// A `Uint8Array` of `analyser.frequencyBinCount` bytes.
  mut data : @core.TypedArray
}

///|
pub fn AudioAnalyser::new(
  audio : Audio,
  fft_size~ : Int32 = 2048,
) -> AudioAnalyser {
  let analyser = audio.context.create_analyser()
  analyser.set_fft_size(fft_size)
  let data = @core.TypedArray::uint8(analyser.frequency_bin_count())
  audio.get_output().connect(analyser.as_node())
  { analyser, data, }
}

///|
pub fn AudioAnalyser::get_frequency_data(
  self : AudioAnalyser,
) -> @core.TypedArray {
  self.analyser.get_byte_frequency_data(self.data)
  self.data
}

///|
pub fn AudioAnalyser::get_average_frequency(self : AudioAnalyser) -> Double {
  let mut value = 0.0
  let data = self.get_frequency_data()
  for i in 0..<data.length() {
    value += data.get(i)
  }
  value / data.length().to_double()
}
