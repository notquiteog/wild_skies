-- Public option keys and defaults are shared by every generation.
return {
    { key = "density", label = "SKY DENSITY", type = "choice", default = "med",
      choices = { { "LOW", "low" }, { "MED", "med" }, { "HIGH", "high" } } },
    { key = "size", label = "BIRD SIZE", type = "choice", default = "normal",
      choices = { { "SMALL", "small" }, { "NORMAL", "normal" },
                  { "LARGE", "large" }, { "HUGE", "huge" } } },
    { key = "bumps", label = "GROUND BATTLES", type = "toggle", default = true },
    -- no game of this era ships flying-pose overworld art, so the sky
    -- composes one.  AUTO keeps bird-shaped species flapping (their
    -- class sheet, coloured on Gold) and gives every other shape its
    -- species-true battle portrait, Crystal 251's extracted Gen 2
    -- portraits included; the other two force one look for everything.
    { key = "skyart", label = "SKY ART", type = "choice",
      default = "auto",
      choices = { { "AUTO", "auto" }, { "PORTRAIT", "portrait" },
                  { "CLASSIC", "classic" } } },
    -- simulated flight attitude: banking into turns, pitching with
    -- climbs, a flap pulse; pure motion, so it works on any art
    { key = "motion", label = "FLIGHT MOTION", type = "toggle",
      default = true },
  }
