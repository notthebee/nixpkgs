{
  lib,
  buildNpmPackage,
  fetchzip,
  ffmpeg,
  makeWrapper,
  nodejs_24,
  nixosTests,
}:

buildNpmPackage (finalAttrs: {
  pname = "crosspoint-sync";
  version = "0.2.1";

  # Fork build: adds word-level Audiobookshelf alignment on top of upstream.
  src = fetchzip {
    url = "https://git.notthebe.ee/notthebee/crosspoint-sync/archive/43bee79a240f5b4242e91f066ea78cc75a08ba3f.tar.gz";
    hash = "sha256-HhbMayzH2gxF04IyPQcsGHzj04VS0axygHALbjO0z1U=";
  };

  npmDepsHash = "sha256-OyuY6YrLItbwuUTkI2ZrZZZS03DSxmRtO1KFiwLpYTo=";

  # Upstream requires node:sqlite, which is only stable from Node 24 on.
  nodejs = nodejs_24;

  # ffmpeg splits audiobooks that exceed the hosted transcriber's upload cap.
  buildInputs = [ ffmpeg ];

  nativeBuildInputs = [ makeWrapper ];

  # dist/ is gitignored, so the default `npm pack` installer would ship the
  # TypeScript sources without the compiled output. Install the layout the
  # server expects instead: it resolves migrations/, assets/ and extension/
  # relative to dist/, exactly as the upstream image lays them out.
  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --no-save $npmFlags "''${npmFlagsArray[@]}"
    # Pruned dev dependencies leave their scope directories behind.
    find node_modules -maxdepth 1 -type d -empty -delete

    mkdir -p $out/lib/crosspoint-sync
    cp -r dist migrations assets extension node_modules package.json $out/lib/crosspoint-sync/

    makeWrapper ${lib.getExe nodejs_24} $out/bin/crosspoint-sync \
      --add-flags $out/lib/crosspoint-sync/dist/index.js \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]} \
      --set-default NODE_ENV production

    runHook postInstall
  '';

  passthru = {
    tests = { inherit (nixosTests) crosspoint-sync; };
  };

  meta = {
    description = "KOSync-compatible sync server for CrossPoint/CrossInk and KOReader e-readers";
    longDescription = ''
      A self-hostable sync server for CrossPoint / CrossInk e-readers and any
      KOReader device. It speaks the stock kosync protocol, stores reading
      progress per device, and additionally syncs bookmarks, clippings and
      reading statistics. Optional connectors push reading state to external
      services such as Hardcover, Micro.blog, Audiobookshelf and Readwise.
    '';
    homepage = "https://github.com/crosspoint-reader/crosspoint-sync";
    license = lib.licenses.mit;
    mainProgram = "crosspoint-sync";
    maintainers = with lib.maintainers; [ notthebee ];
  };
})
