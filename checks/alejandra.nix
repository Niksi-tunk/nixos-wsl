{
  runCommand,
  alejandra,
  ...
}:
runCommand "check-alejandra" {nativeBuildInputs = [alejandra];} ''
  alejandra -c ${./..}
  touch $out
''
