({ pkgs, firefoxPackage, ... }:
{
  name = firefoxPackage.unwrapped.pname;
  nodes.machine =
    { modulesPath, ... }:

    { imports = [ (modulesPath + "/../tests/common/x11.nix") ];
      environment.systemPackages = [
        firefoxPackage
      ];
    };

  testScript = ''
      machine.wait_for_x()

      with subtest("Wait until Firefox has finished loading the Valgrind docs page"):
          machine.execute(
              "xterm -e '${firefoxPackage.unwrapped.binaryName} file://${pkgs.valgrind.doc}/share/doc/valgrind/html/index.html' >&2 &"
          )
          machine.wait_for_window("Valgrind")
          machine.sleep(20)
          machine.screenshot("screen")
    '';

})
