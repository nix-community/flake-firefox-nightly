({ pkgs, firefoxPackage, ... }:
{
  name = firefoxPackage.unwrapped.pname;
  nodes.machine =
    { modulesPath, ... }:

    { imports = [ (modulesPath + "/../tests/common/x11.nix") ];
      environment.systemPackages = [
        firefoxPackage
      ];
      services.journald.console = "/dev/ttyS0";
    };

  testScript = ''
      machine.wait_for_x()

      with subtest("Wait until Firefox has finished loading the Valgrind docs page"):
          machine.succeed(
              "systemd-run -E DISPLAY=:0 ${firefoxPackage.unwrapped.binaryName} file://${pkgs.valgrind.doc}/share/doc/valgrind/html/index.html"
              , timeout=60
          )
          machine.wait_for_window("Valgrind", timeout=120)
          machine.sleep(20)
          machine.screenshot("screen")
    '';

})
