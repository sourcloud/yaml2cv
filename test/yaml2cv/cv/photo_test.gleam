import gleam/bit_array
import simplifile
import yaml2cv/cv.{Jpeg, Photo, Png}
import yaml2cv/cv/photo.{InvalidImage, NotAPhotoDataUri, TooLarge, TooManyPixels}

fn fixture(name: String) -> BitArray {
  let assert Ok(bytes) = simplifile.read_bits("test/fixtures/" <> name)
  bytes
}

fn data_uri(media_type: String, bytes: BitArray) -> String {
  "data:" <> media_type <> ";base64," <> bit_array.base64_encode(bytes, True)
}

/// A PNG signature and `IHDR` chunk claiming the given size, no pixel data.
fn png_header(width: Int, height: Int) -> BitArray {
  <<
    0x89, "PNG\r\n", 0x1A, "\n", 13:32, "IHDR", width:32, height:32, 8, 2, 0, 0,
    0, 0:32,
  >>
}

/// A JPEG start marker, an `APP0` segment and a baseline `SOF0` segment
/// claiming the given size.
fn jpeg_header(width: Int, height: Int) -> BitArray {
  <<
    0xFF, 0xD8, 0xFF, 0xE0, 16:16, "JFIF", 0, 1, 1, 0, 1:16, 1:16, 0, 0, 0xFF,
    0xC0, 17:16, 8, height:16, width:16, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1,
  >>
}

pub fn reads_jpeg_data_uri_test() {
  let bytes = fixture("photo.jpg")
  assert photo.from_data_uri(data_uri("image/jpeg", bytes))
    == Ok(Photo(format: Jpeg, data: bytes))
}

pub fn reads_png_data_uri_test() {
  let bytes = fixture("photo.png")
  assert photo.from_data_uri(data_uri("image/png", bytes))
    == Ok(Photo(format: Png, data: bytes))
}

pub fn ignores_whitespace_in_base64_test() {
  let bytes = fixture("photo.png")
  let assert <<head:bytes-size(9), rest:bytes>> =
    bit_array.base64_encode(bytes, True) |> bit_array.from_string
  let assert Ok(head) = bit_array.to_string(head)
  let assert Ok(rest) = bit_array.to_string(rest)
  let uri = "data:image/png;base64," <> head <> " \n" <> rest
  assert photo.from_data_uri(uri) == Ok(Photo(format: Png, data: bytes))
}

pub fn reads_dimensions_of_jpeg_header_test() {
  assert photo.from_data_uri(data_uri("image/jpeg", jpeg_header(600, 771)))
    == Ok(Photo(format: Jpeg, data: jpeg_header(600, 771)))
}

pub fn rejects_other_uris_test() {
  assert photo.from_data_uri("photo.jpg") == Error(NotAPhotoDataUri)
  assert photo.from_data_uri("https://example.com/me.jpg")
    == Error(NotAPhotoDataUri)
  assert photo.from_data_uri(data_uri("image/svg+xml", <<"<svg/>">>))
    == Error(NotAPhotoDataUri)
  assert photo.from_data_uri("data:image/png,raw") == Error(NotAPhotoDataUri)
}

pub fn rejects_invalid_base64_test() {
  assert photo.from_data_uri("data:image/png;base64,***") == Error(InvalidImage)
}

pub fn rejects_content_not_matching_media_type_test() {
  assert photo.from_data_uri(data_uri("image/jpeg", fixture("photo.png")))
    == Error(InvalidImage)
  assert photo.from_data_uri(data_uri("image/png", <<"not an image">>))
    == Error(InvalidImage)
}

pub fn rejects_jpeg_without_frame_header_test() {
  let truncated = <<0xFF, 0xD8, 0xFF, 0xE0, 16:16, "JFIF">>
  assert photo.from_data_uri(data_uri("image/jpeg", truncated))
    == Error(InvalidImage)
}

pub fn rejects_oversized_file_test() {
  let padding = <<0:size({ photo.max_bytes + 1 - 33 } * 8)>>
  let bytes = bit_array.append(png_header(10, 10), padding)
  assert photo.from_data_uri(data_uri("image/png", bytes))
    == Error(TooLarge(max_bytes: photo.max_bytes))
}

pub fn rejects_too_many_pixels_test() {
  let max = photo.max_side
  assert photo.from_data_uri(data_uri("image/png", png_header(max, max)))
    |> is_ok
  assert photo.from_data_uri(data_uri("image/png", png_header(max + 1, 10)))
    == Error(TooManyPixels(max_side: max))
  assert photo.from_data_uri(data_uri("image/jpeg", jpeg_header(10, max + 1)))
    == Error(TooManyPixels(max_side: max))
}

fn is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

pub fn names_the_file_after_the_format_test() {
  assert photo.file_name(Photo(format: Jpeg, data: <<>>)) == "photo.jpg"
  assert photo.file_name(Photo(format: Png, data: <<>>)) == "photo.png"
}
