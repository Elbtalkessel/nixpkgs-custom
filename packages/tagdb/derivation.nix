{ python3Packages }:
with python3Packages;
buildPythonApplication {
  pname = "pytagdb";
  version = "0.0.1";
  src = ./src;
}
