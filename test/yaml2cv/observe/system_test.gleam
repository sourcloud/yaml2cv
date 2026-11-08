import gleam/option.{None, Some}
import yaml2cv/observe/system

pub fn parses_load_averages_test() {
  assert system.parse_loadavg("0.40 0.30 0.20 1/123 4567\n")
    == Ok(#(0.4, 0.3, 0.2))
  assert system.parse_loadavg("") == Error(Nil)
}

pub fn computes_host_memory_use_from_meminfo_test() {
  let meminfo =
    "MemTotal:        8000000 kB\nMemFree:          500000 kB\nMemAvailable:    2000000 kB\n"
  assert system.parse_meminfo(meminfo) == Ok(75)
  assert system.parse_meminfo("MemFree: 1 kB\n") == Error(Nil)
}

pub fn computes_cgroup_memory_use_test() {
  assert system.cgroup_memory("268435456\n", "536870912\n") == Ok(50)
  // Without a limit the host figure applies.
  assert system.cgroup_memory("268435456\n", "max\n") == Error(Nil)
}

pub fn parses_io_pressure_test() {
  let pressure =
    "some avg10=1.25 avg60=0.50 avg300=0.10 total=12345\nfull avg10=0.75 avg60=0.20 avg300=0.05 total=6789\n"
  assert system.parse_pressure(pressure) == Ok(1.25)
  assert system.parse_pressure("") == Error(Nil)
}

pub fn parses_disk_use_from_df_test() {
  let df =
    "Filesystem     1024-blocks    Used Available Capacity Mounted on\noverlay           61255492 4271164  53842996       8% /\n"
  assert system.parse_df(df) == Ok(8)
  assert system.parse_df("df: /nope: No such file or directory\n") == Error(Nil)
}

pub fn samples_status_without_crashing_test() {
  // Values depend on the machine; on non-Linux hosts most are unavailable.
  let status = system.sample("build/test-render")
  case status.disk {
    Some(percent) -> {
      assert percent >= 0 && percent <= 100
    }
    None -> Nil
  }
}
