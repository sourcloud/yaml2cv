import yaml2cv/cli/arguments.{
  File, Help, Render, Serve, Stdin, Stdout, ToFile, Validate,
}

pub fn no_arguments_start_the_server_test() {
  let assert Ok(Serve) = arguments.parse([])
  let assert Ok(Serve) = arguments.parse(["serve"])
}

pub fn help_test() {
  let assert Ok(Help) = arguments.parse(["help"])
  let assert Ok(Help) = arguments.parse(["-h"])
  let assert Ok(Help) = arguments.parse(["--help"])
}

pub fn unknown_command_is_a_usage_error_test() {
  let assert Error("unknown command \"rendr\"") = arguments.parse(["rendr"])
  let assert Error(_) = arguments.parse(["serve", "x"])
}

pub fn render_writes_pdf_next_to_input_test() {
  let assert Ok(Render(
    jobs: [
      #(File("cv-en.yaml"), ToFile("cv-en.pdf")),
      #(File("dir/cv.yml"), ToFile("dir/cv.pdf")),
      #(File("notes.txt"), ToFile("notes.txt.pdf")),
    ],
    json: False,
  )) = arguments.parse(["render", "cv-en.yaml", "dir/cv.yml", "notes.txt"])
}

pub fn render_needs_an_input_test() {
  let assert Error("render needs at least one input") =
    arguments.parse(["render"])
  let assert Error("validate needs at least one input") =
    arguments.parse(["validate", "--json"])
}

pub fn render_stdin_goes_to_stdout_test() {
  let assert Ok(Render(jobs: [#(Stdin, Stdout)], json: False)) =
    arguments.parse(["render", "-"])
}

pub fn stdin_only_once_test() {
  let assert Error("standard input (-) can be read only once") =
    arguments.parse(["render", "-", "-"])
}

pub fn output_file_test() {
  let assert Ok(Render(jobs: [#(File("cv.yaml"), ToFile("out.pdf"))], ..)) =
    arguments.parse(["render", "-o", "out.pdf", "cv.yaml"])
  let assert Ok(Render(jobs: [#(Stdin, ToFile("out.pdf"))], ..)) =
    arguments.parse(["render", "-", "-o", "out.pdf"])
  let assert Ok(Render(jobs: [#(File("cv.yaml"), Stdout)], ..)) =
    arguments.parse(["render", "cv.yaml", "-o", "-"])
}

pub fn output_file_needs_one_input_test() {
  let assert Error("-o needs exactly one input; use --out-dir for several") =
    arguments.parse(["render", "-o", "x.pdf", "a.yaml", "b.yaml"])
}

pub fn option_without_value_test() {
  let assert Error("-o needs a value") =
    arguments.parse(["render", "a.yaml", "-o"])
  let assert Error("--out-dir needs a value") =
    arguments.parse(["render", "a.yaml", "--out-dir"])
}

pub fn out_dir_test() {
  let assert Ok(Render(
    jobs: [
      #(File("de/cv.yaml"), ToFile("build/cv.pdf")),
      #(File("cv-en.yml"), ToFile("build/cv-en.pdf")),
    ],
    json: True,
  )) =
    arguments.parse([
      "render", "--json", "--out-dir", "build/", "de/cv.yaml", "cv-en.yml",
    ])
  let assert Ok(Render(jobs: [#(File("a.yaml"), ToFile("out/a.pdf"))], ..)) =
    arguments.parse(["render", "--out-dir=out", "a.yaml"])
}

pub fn out_dir_rejects_stdin_test() {
  let assert Error("standard input (-) cannot be used with --out-dir") =
    arguments.parse(["render", "--out-dir", "out", "-"])
}

pub fn out_dir_and_output_file_exclude_each_other_test() {
  let assert Error("-o and --out-dir cannot be combined") =
    arguments.parse(["render", "-o", "a.pdf", "--out-dir", "out", "a.yaml"])
}

pub fn duplicate_outputs_are_rejected_test() {
  let assert Error("de/cv.yaml and en/cv.yaml would both write out/cv.pdf") =
    arguments.parse(["render", "--out-dir", "out", "de/cv.yaml", "en/cv.yaml"])
  let assert Error("cv.yaml and cv.yml would both write cv.pdf") =
    arguments.parse(["render", "cv.yaml", "cv.yml"])
}

pub fn unknown_option_test() {
  let assert Error("unknown option \"--jsn\"") =
    arguments.parse(["render", "--jsn", "a.yaml"])
}

pub fn double_dash_ends_options_test() {
  let assert Ok(Render(jobs: [#(File("-o.yaml"), ToFile("-o.pdf"))], ..)) =
    arguments.parse(["render", "--", "-o.yaml"])
}

pub fn validate_test() {
  let assert Ok(Validate(inputs: [File("a.yaml"), Stdin], json: True)) =
    arguments.parse(["validate", "a.yaml", "-", "--json"])
}

pub fn validate_has_no_output_options_test() {
  let assert Error("validate does not write files; -o is not allowed") =
    arguments.parse(["validate", "-o", "x", "a.yaml"])
  let assert Error("validate does not write files; --out-dir is not allowed") =
    arguments.parse(["validate", "--out-dir", "x", "a.yaml"])
}
