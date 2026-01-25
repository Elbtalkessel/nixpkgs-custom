{
  config,
  ...
}:
let
  pytagdb = config.languages.python.import ./src { };
in
{
  languages = {
    python = {
      enable = true;
      directory = "${config.devenv.root}/src";
      uv = {
        enable = true;
      };
    };
  };

  packages = [ pytagdb ];

  outputs = {
    inherit pytagdb;
  };
}
