import "./index.css";
import { Composition } from "remotion";
import { HackathonDevlogComposition } from "./Composition";

export const RemotionRoot = () => {
  return (
    <>
      <Composition
        id="HackathonDevlog"
        component={HackathonDevlogComposition}
        durationInFrames={1080}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
