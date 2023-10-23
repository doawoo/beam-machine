#! elixir

orig_cwd = File.cwd!()
file_dir = __ENV__.file |> Path.dirname()

temp_workdir = System.tmp_dir!() |> Path.join(:crypto.strong_rand_bytes(8) |> Base.encode16())
File.mkdir_p!(temp_workdir)
File.cd!(temp_workdir)

Mix.install([{:tesla, "~> 1.4"}, {:jason, "~> 1.3"}])

script_version = "0.2.0"
default_openssl_version = "1.1.1s"

usage = """
  mkerlang v#{script_version} - build a static Erlang release tar archive (Usually for use in Burrito)

  args:
    --otp-version=[x.y.z] (The OTP version that will be built) [REQUIRED]
    --arch=[aarch64, x86_64, riscv64] (The arch to build erlang for, defaults to the current host arch)
    --os=[linux, darwin] (The OS Erlang is being built for)
    --abi=[gnu, musl] (The ABI of the target system, ignored if building for MacOS)
    --openssl-version=[x.y.z(w)] (OpenSSL version to statically link into the release, defaults to #{default_openssl_version})
"""

options = [
  otp_version: :string,
  arch: :string,
  os: :string,
  abi: :string,
  openssl_version: :string,
  toolchain_dir: :string
]

defmodule ScriptUtils do
  @nerves_toolchain_url "https://api.github.com/repos/nerves-project/toolchains/releases/tags/v1.8.0"

  def get_current_cpu do
    :erlang.system_info(:system_architecture)
    |> to_string()
    |> String.downcase()
    |> String.split("-")
    |> List.first()
  end

  def get_current_os do
    case :os.type() do
      {:win32, _} -> "windows"
      {:unix, :darwin} -> "darwin"
      {:unix, :linux} -> "linux"
    end
  end

  def build_linux_toolchain_name(cpu, abi) do
    "#{cpu}-nerves-linux-#{abi}"
  end

  def openssl_target(:linux, :x86_64), do: "linux-x86_64"
  def openssl_target(:linux, :aarch64), do: "linux-aarch64"
  def openssl_target(:linux, :riscv64), do: "linux64-riscv64"
  def openssl_target(:linux, :mipsel), do: "linux-mips64"

  def openssl_target(:darwin, :x86_64), do: "darwin64-x86_64-cc"
  def openssl_target(:darwin, :aarch64), do: "darwin64-arm64-cc"

  def clang_target(:x86_64), do: "x86_64-apple-macos11"
  def clang_target(:aarch64), do: "arm64-apple-macos11"

  def darwin_erlang_target(:x86_64), do: "x86_64-apple-darwin"
  def darwin_erlang_target(:aarch64), do: "aarch64-apple-darwin"

  def build_compiler_env(cpu, abi, bin_path) do
    [
      {"CC", Path.join([bin_path, "/#{ScriptUtils.build_linux_toolchain_name(cpu, abi)}-cc"])},
      {"CXX", Path.join([bin_path, "/#{ScriptUtils.build_linux_toolchain_name(cpu, abi)}-c++"])},
      {"AR", Path.join([bin_path, "/#{ScriptUtils.build_linux_toolchain_name(cpu, abi)}-ar"])},
      {"LD", Path.join([bin_path, "/#{ScriptUtils.build_linux_toolchain_name(cpu, abi)}-ld"])},
      {"LIBTOOL",
       Path.join([bin_path, "/#{ScriptUtils.build_linux_toolchain_name(cpu, abi)}-libtool"])},
      {"RANLIB",
       Path.join([bin_path, "/#{ScriptUtils.build_linux_toolchain_name(cpu, abi)}-ranlib"])},
      {"STRIP",
       Path.join([bin_path, "/#{ScriptUtils.build_linux_toolchain_name(cpu, abi)}-strip"])}
    ]
  end

  def fetch_and_extract_toolchain(url) do
    IO.puts("Downloading #{url}...")
    "wget #{url}" |> String.to_charlist() |> :os.cmd()
    file_name = String.split(url, "/") |> List.last()
    [] = "tar xf #{file_name}" |> String.to_charlist() |> :os.cmd()
  end

  def fetch_and_extract(base_url, file_name) do
    "wget #{base_url}/#{file_name}" |> String.to_charlist() |> :os.cmd()
    [] = "tar xzf #{file_name}" |> String.to_charlist() |> :os.cmd()
  end

  def fetch_local_linux_toolchain(cpu, abi, toolchain_override_dir) do
    files = File.ls!(toolchain_override_dir)

    found =
      Enum.find(files, fn path ->
        String.contains?(
          path,
          "nerves_toolchain_#{cpu}_nerves_linux_#{abi}-darwin_arm"
        )
      end)

    if found do
      found = Path.join(toolchain_override_dir, found)
      [] = "tar xf #{found}" |> String.to_charlist() |> :os.cmd()
      files = Path.join([File.cwd!(), "/nerves_toolchain_*"]) |> Path.wildcard()
      directory = List.delete(files, found) |> List.first()

      IO.puts("Local Toolchain Directory: #{directory}")

      name = build_linux_toolchain_name(cpu, abi)
      bin_path = Path.join([directory, "/bin"])
      sysroot_path = Path.join([directory, "/#{name}/sysroot"])
      compiler_env = build_compiler_env(cpu, abi, bin_path)

      IO.puts("Compiler Env: ")
      IO.puts("#{inspect(compiler_env)}")

      %{
        bin_path: bin_path,
        sysroot_path: sysroot_path,
        compiler_env: compiler_env
      }
    else
      raise "Cannot find a matching Nerves toolchain to download for that platform/ABI combination!"
    end
  end

  def fetch_linux_toolchain(cpu, abi, toolchain_override_dir) do
    if toolchain_override_dir != nil do
      fetch_local_linux_toolchain(cpu, abi, toolchain_override_dir)
    else
      resp = Tesla.get!(@nerves_toolchain_url, headers: [{"User-Agent", "ErlangBuilder"}])
      data = Jason.decode!(resp.body)

      found =
        data["assets"]
        |> Enum.find(fn asset ->
          String.contains?(
            asset["browser_download_url"],
            "nerves_toolchain_#{cpu}_nerves_linux_#{abi}-darwin_arm"
          )
        end)

      if found do
        fetch_and_extract_toolchain(found["browser_download_url"])
        files = Path.join([File.cwd!(), "/nerves_toolchain_*"]) |> Path.wildcard()
        archive = Enum.find(files, fn s -> String.contains?(s, ".tar.xz") end)
        directory = List.delete(files, archive) |> List.first()

        File.rm!(archive)

        IO.puts("Toolchain Directory: #{directory}")

        name = build_linux_toolchain_name(cpu, abi)
        bin_path = Path.join([directory, "/bin"])
        sysroot_path = Path.join([directory, "/#{name}/sysroot"])
        compiler_env = build_compiler_env(cpu, abi, bin_path)

        IO.puts("Compiler Env: ")
        IO.puts("#{inspect(compiler_env)}")

        %{
          bin_path: bin_path,
          sysroot_path: sysroot_path,
          compiler_env: compiler_env
        }
      else
        raise "Cannot find a matching Nerves toolchain to download for that platform/ABI combination!"
      end
    end
  end

  def print_fatal(val) do
    IO.puts("[!] #{val}")
    System.halt(1)
  end

  def exec_command_in_cwd(command, env) do
    {_, result} =
      System.cmd(
        "/bin/bash",
        [
          "-c",
          command
        ],
        cd: File.cwd!(),
        into: IO.stream(),
        env: env,
        stderr_to_stdout: true
      )

    if result != 0 do
      raise "Command failed! --> #{inspect(command)}"
      System.halt(1)
    end
  end

  def arch_to_atom("x86_64"), do: :x86_64
  def arch_to_atom("aarch64"), do: :aarch64
  def arch_to_atom("riscv64"), do: :riscv64
  def arch_to_atom("mipsel"), do: :mipsel
  def arch_to_atom(_), do: get_current_cpu() |> arch_to_atom()

  def os_to_atom("linux"), do: :linux
  def os_to_atom("darwin"), do: :darwin
  def os_to_atom(_), do: get_current_os() |> os_to_atom()

  def abi_to_atom("gnu"), do: :gnu
  def abi_to_atom("musl"), do: :musl
end

required_path_commands = ["wget", "clang", "make", "autoconf", "perl", "tar"]

if Enum.any?(required_path_commands, fn command ->
     match?({_, 1}, System.cmd("which", [command]))
   end) do
  ScriptUtils.print_fatal(
    "Required programs (#{inspect(required_path_commands)}) were missing from path"
  )
end

{args, _rest} = OptionParser.parse!(System.argv(), switches: options)

if !Keyword.has_key?(args, :otp_version) do
  IO.puts(usage)
  ScriptUtils.print_fatal("Required parameter --otp_version was not provided!")
end

target_erlang_version = Keyword.get(args, :otp_version)
target_openssl_version = Keyword.get(args, :openssl_version, default_openssl_version)

toolchain_override_dir = cond do
  Keyword.get(args, :toolchain_dir) != nil -> Keyword.get(args, :toolchain_dir)
  System.get_env("TOOLCHAIN_DIR") != nil -> System.get_env("TOOLCHAIN_DIR")
  true -> nil
end

IO.puts("Host OS: #{ScriptUtils.get_current_os()}")
IO.puts("Host Arch: #{ScriptUtils.get_current_cpu()}")
IO.puts("Build Dir: #{temp_workdir}")

if toolchain_override_dir != nil do
  IO.puts("Toolchain Override Directory: #{toolchain_override_dir}")
end

IO.puts("----------")

target_arch =
  Keyword.get(args, :arch, ScriptUtils.get_current_cpu()) |> ScriptUtils.arch_to_atom()

target_os = Keyword.get(args, :os, ScriptUtils.get_current_os()) |> ScriptUtils.os_to_atom()
target_abi = Keyword.get(args, :abi, "gnu") |> ScriptUtils.abi_to_atom()

IO.puts("Target Arch: #{target_arch}")
IO.puts("Target OS: #{target_os}")

if target_os == :linux do
  IO.puts("Target ABI: #{target_abi}")
end

IO.puts("----------")

IO.puts("Target Erlang Version: #{target_erlang_version}")
IO.puts("Target OpenSSL Version: #{target_openssl_version}")
IO.puts("----------")

#### Fetching

IO.puts("-> Fetch & Extract: OpenSSL...")

ScriptUtils.fetch_and_extract(
  "https://www.openssl.org/source",
  "openssl-#{target_openssl_version}.tar.gz"
)

IO.puts("-> Fetch & Extract: Erlang...")

ScriptUtils.fetch_and_extract(
  "https://github.com/erlang/otp/releases/download/OTP-#{target_erlang_version}",
  "otp_src_#{target_erlang_version}.tar.gz"
)

IO.puts("----------")

result =
  if target_os == :linux do
    IO.puts("-> Fetch & Extract: Toolchain")
    ScriptUtils.fetch_linux_toolchain(target_arch, target_abi, toolchain_override_dir)
  else
    IO.puts("-> Using Native Toolchain")
    sysroot_path = Path.join([temp_workdir, "/sysroot"])

    compiler_env = [
      {"CC", "clang -target #{ScriptUtils.clang_target(target_arch)}"},
      {"CXX", "clang++ -target #{ScriptUtils.clang_target(target_arch)}"},
      {"RANLIB", "/usr/bin/ranlib"},
      {"AR", "/usr/bin/ar"}
    ]

    File.mkdir!(sysroot_path)

    %{
      sysroot_path: sysroot_path,
      compiler_env: compiler_env
    }
  end

IO.puts("-> Build: OpenSSL...")
Path.join(temp_workdir, "openssl-#{target_openssl_version}") |> File.cd!()

ScriptUtils.exec_command_in_cwd(
  "./Configure #{ScriptUtils.openssl_target(target_os, target_arch)} no-shared no-tests --prefix=#{result.sysroot_path} && make -j && make install_sw",
  result.compiler_env
)

File.cd!(temp_workdir)

if target_os == :linux do
  IO.puts("-> Generate: XComp Config...")

  compiled_config =
    EEx.eval_file("#{file_dir}/erlang-xcomp-template.conf.eex",
      bin_path: result.bin_path,
      toolchain_prefix: ScriptUtils.build_linux_toolchain_name(target_arch, target_abi),
      sysroot_path: result.sysroot_path,
      target_arch: target_arch,
      target_abi: target_abi,
      target_os: target_os,
      additional_cflags: System.get_env("ADDITIONAL_CFLAGS", ""),
      additional_cxxflags: System.get_env("ADDITIONAL_CXXFLAGS", "")
    )

  File.write!("erlang-xcomp-config-beam-machine.conf", compiled_config)

  IO.puts("--> Boostrap Erlang...")
  Path.join(temp_workdir, "otp_src_#{target_erlang_version}") |> File.cd!()

  ScriptUtils.exec_command_in_cwd(
    "./configure --enable-bootstrap-only --without-termcap --without-javac --without-jinterface --without-wx && make -j",
    []
  )

  IO.puts("--> Cross-Compile Erlang...")

  ScriptUtils.exec_command_in_cwd(
    "./otp_build configure --xcomp-conf=#{Path.join([temp_workdir, "/erlang-xcomp-config-beam-machine.conf"])} && make -j",
    []
  )
else
  IO.puts("--> Boostrap Erlang...")
  Path.join(temp_workdir, "otp_src_#{target_erlang_version}") |> File.cd!()

  ScriptUtils.exec_command_in_cwd(
    "./configure --enable-bootstrap-only --without-termcap --without-javac --without-jinterface --without-wx && make -j",
    [{"RANLIB", "/usr/bin/ranlib"}, {"AR", "/usr/bin/ar"}]
  )

  IO.puts("--> Compile Erlang...")

  erlang_configure_flags =
    "--disable-parallel-configure --without-javac --without-termcap --without-jinterface --disable-dynamic-ssl-lib --without-wx --with-ssl='#{result.sysroot_path}'"

  erlang_env = [
    {"erl_xcomp_sysroot", result.sysroot_path},
    {"CC", "clang -target #{ScriptUtils.clang_target(target_arch)}"},
    {"CXX", "clang++ -target #{ScriptUtils.clang_target(target_arch)}"},
    {"LDFLAGS", "-L#{result.sysroot_path}/lib"},
    {"CFLAGS",
     "-O2 -g -L#{result.sysroot_path}/lib -I#{result.sysroot_path}/include"},
    {"CXXFLAGS",
     "-O2 -g -L#{result.sysroot_path}/lib -I#{result.sysroot_path}/include"},
    {"RANLIB", "/usr/bin/ranlib"},
    {"AR", "/usr/bin/ar"}
  ]

  ScriptUtils.exec_command_in_cwd(
    "./configure #{erlang_configure_flags} --host=#{ScriptUtils.darwin_erlang_target(target_arch)} --build=$(erts/autoconf/config.guess) && make -j",
    erlang_env
  )
end

IO.puts("-> Build & Pack Release...")

release_name =
  if target_os == :linux do
    "otp_#{target_erlang_version}_#{target_os}_#{target_abi}_#{target_arch}_ssl_#{target_openssl_version}"
  else
    "otp_#{target_erlang_version}_#{target_os}_#{target_arch}_ssl_#{target_openssl_version}"
  end

release_root = Path.join(orig_cwd, release_name)
ScriptUtils.exec_command_in_cwd("make release -j", [{"RELEASE_ROOT", release_root}])

File.cd!(orig_cwd)
ScriptUtils.exec_command_in_cwd("tar czf #{release_name}.tar.gz ./#{release_name}/", [])

IO.puts("-> Cleaning Up")
File.rm_rf!(temp_workdir)
File.rm_rf!("./#{release_name}/")

IO.puts("-> Done!")
