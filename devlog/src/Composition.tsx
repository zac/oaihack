import {
  AbsoluteFill,
  Easing,
  Sequence,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import {
  devlogSessions,
  devlogSummary,
  type DevlogSession,
} from "./devlog-data.generated";

const colors = {
  backgroundTop: "#031725",
  backgroundBottom: "#052f45",
  panel: "rgba(8, 30, 43, 0.78)",
  panelBorder: "rgba(141, 196, 223, 0.22)",
  text: "#f3fbff",
  muted: "#9fc4d6",
  accent: "#2ed9c4",
  accentWarm: "#ffbe59",
  accentHot: "#ff7a5d",
  timeline: "rgba(150, 208, 229, 0.5)",
};

const displayFont =
  '"Avenir Next", "Trebuchet MS", "Helvetica Neue", Helvetica, sans-serif';
const monoFont =
  '"SF Mono", Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace';

const HACKATHON_DAY = "Thursday, February 5, 2026";
const DEADLINE = "4:00 PM PT";

const clamp = {
  extrapolateLeft: "clamp" as const,
  extrapolateRight: "clamp" as const,
};

const formatMinutesCompact = (minutes: number) => {
  const safeMinutes = Math.max(0, minutes);
  const hours = Math.floor(safeMinutes / 60);
  const remMinutes = safeMinutes - hours * 60;

  if (hours === 0) {
    return `${remMinutes}m`;
  }

  if (remMinutes === 0) {
    return `${hours}h`;
  }

  return `${hours}h ${remMinutes}m`;
};

const formatRangeCompact = (range: [number, number]) => {
  return `${formatMinutesCompact(range[0])} -> ${formatMinutesCompact(range[1])}`;
};

const truncate = (value: string, maxLength: number) => {
  if (value.length <= maxLength) {
    return value;
  }

  return `${value.slice(0, maxLength - 1)}...`;
};

const getTimeSavedMidpoint = (session: DevlogSession) => {
  if (!session.timeSavedRangeMinutes) {
    return 0;
  }

  return (
    (session.timeSavedRangeMinutes[0] + session.timeSavedRangeMinutes[1]) / 2
  );
};

const Backdrop = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  const leftOrbX = interpolate(frame, [0, durationInFrames], [-140, 80], clamp);
  const rightOrbY = interpolate(frame, [0, durationInFrames], [120, -80], clamp);
  const pulse = interpolate(frame, [0, durationInFrames], [0.7, 1], {
    ...clamp,
    easing: Easing.inOut(Easing.sin),
  });

  return (
    <AbsoluteFill
      style={{
        background: `linear-gradient(180deg, ${colors.backgroundTop} 0%, ${colors.backgroundBottom} 100%)`,
        overflow: "hidden",
      }}
    >
      <div
        style={{
          position: "absolute",
          width: 680,
          height: 680,
          borderRadius: 9999,
          left: leftOrbX,
          top: -260,
          background:
            "radial-gradient(circle, rgba(46,217,196,0.24) 0%, rgba(46,217,196,0) 70%)",
          transform: `scale(${pulse})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 720,
          height: 720,
          borderRadius: 9999,
          right: -260,
          bottom: rightOrbY,
          background:
            "radial-gradient(circle, rgba(255,122,93,0.18) 0%, rgba(255,122,93,0) 70%)",
        }}
      />
    </AbsoluteFill>
  );
};

const IntroScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const reveal = spring({
    frame,
    fps,
    config: { damping: 200 },
  });

  const subtitle = "Codex devlogs transformed into demo-ready judging evidence.";
  const visibleChars = Math.floor(
    interpolate(frame, [0, 2.2 * fps], [0, subtitle.length], clamp),
  );
  const subtitleSlice = subtitle.slice(0, visibleChars);

  return (
    <AbsoluteFill
      style={{
        padding: "126px 140px",
        color: colors.text,
        fontFamily: displayFont,
      }}
    >
      <div
        style={{
          width: 1260,
          opacity: reveal,
          transform: `translateY(${interpolate(reveal, [0, 1], [28, 0])}px)`,
        }}
      >
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            borderRadius: 999,
            border: `1px solid ${colors.panelBorder}`,
            backgroundColor: "rgba(6, 36, 52, 0.64)",
            padding: "10px 16px",
            letterSpacing: "0.06em",
            textTransform: "uppercase",
            fontSize: 19,
            color: colors.muted,
          }}
        >
          Hackathon Day Storyboard
        </div>
        <h1
          style={{
            margin: "24px 0 16px",
            fontSize: 90,
            lineHeight: 1.02,
            fontWeight: 750,
            letterSpacing: "-0.03em",
          }}
        >
          Codex Devlog
          <br />
          Visualization
        </h1>
        <p
          style={{
            fontSize: 35,
            lineHeight: 1.35,
            margin: 0,
            color: colors.muted,
          }}
        >
          {subtitleSlice}
        </p>
      </div>
      <div
        style={{
          marginTop: "auto",
          width: 790,
          borderRadius: 24,
          border: `1px solid ${colors.panelBorder}`,
          background: colors.panel,
          padding: "24px 28px",
          display: "flex",
          flexDirection: "column",
          gap: 10,
        }}
      >
        <div
          style={{
            color: colors.accentWarm,
            fontSize: 24,
            letterSpacing: "0.05em",
            textTransform: "uppercase",
          }}
        >
          Submission Deadline
        </div>
        <div style={{ fontSize: 36, fontWeight: 650 }}>
          {HACKATHON_DAY} at {DEADLINE}
        </div>
      </div>
    </AbsoluteFill>
  );
};

type MetricCardProps = {
  frame: number;
  fps: number;
  delayFrames: number;
  title: string;
  value: string;
  detail: string;
  accentColor: string;
};

const MetricCard = ({
  frame,
  fps,
  delayFrames,
  title,
  value,
  detail,
  accentColor,
}: MetricCardProps) => {
  const reveal = spring({
    frame: frame - delayFrames,
    fps,
    config: { damping: 200 },
  });

  return (
    <div
      style={{
        borderRadius: 22,
        border: `1px solid ${colors.panelBorder}`,
        background: colors.panel,
        padding: "24px 24px 22px",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        opacity: reveal,
        transform: `translateY(${interpolate(reveal, [0, 1], [20, 0])}px)`,
      }}
    >
      <div
        style={{
          fontSize: 20,
          color: colors.muted,
          textTransform: "uppercase",
          letterSpacing: "0.05em",
        }}
      >
        {title}
      </div>
      <div
        style={{
          marginTop: 14,
          fontSize: 54,
          lineHeight: 1,
          fontWeight: 720,
          color: accentColor,
          fontFamily: monoFont,
        }}
      >
        {value}
      </div>
      <div style={{ marginTop: 14, fontSize: 24, color: colors.muted }}>{detail}</div>
    </div>
  );
};

const KpiScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const sessionCountAnimated = Math.round(
    interpolate(frame, [0, 1.4 * fps], [0, devlogSummary.sessionCount], clamp),
  );
  const testedCountAnimated = Math.round(
    interpolate(frame, [0, 1.6 * fps], [0, devlogSummary.testedSessionCount], clamp),
  );
  const actionCountAnimated = Math.round(
    interpolate(frame, [0, 1.7 * fps], [0, devlogSummary.totalCodexActions], clamp),
  );

  const minSavedAnimated = Math.round(
    interpolate(frame, [0, 1.8 * fps], [0, devlogSummary.totalTimeRangeMinutes[0]], clamp),
  );
  const maxSavedAnimated = Math.round(
    interpolate(frame, [0, 1.8 * fps], [0, devlogSummary.totalTimeRangeMinutes[1]], clamp),
  );

  return (
    <AbsoluteFill
      style={{
        padding: "88px 112px",
        color: colors.text,
        fontFamily: displayFont,
      }}
    >
      <h2
        style={{
          margin: 0,
          fontSize: 62,
          lineHeight: 1.1,
          letterSpacing: "-0.02em",
        }}
      >
        Hackathon Activity Snapshot
      </h2>
      <p style={{ margin: "14px 0 30px", fontSize: 27, color: colors.muted }}>
        Timeline window {devlogSummary.firstSession} {"->"}{" "}
        {devlogSummary.lastSession} PT
      </p>
      <div
        style={{
          flex: 1,
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gridTemplateRows: "1fr 1fr",
          gap: 22,
        }}
      >
        <MetricCard
          frame={frame}
          fps={fps}
          delayFrames={0}
          title="Sessions logged"
          value={`${sessionCountAnimated}`}
          detail="Recorded in codex-log/*.md"
          accentColor={colors.accent}
        />
        <MetricCard
          frame={frame}
          fps={fps}
          delayFrames={8}
          title="Estimated time saved"
          value={formatRangeCompact([minSavedAnimated, maxSavedAnimated])}
          detail="Codex acceleration stated per session"
          accentColor={colors.accentWarm}
        />
        <MetricCard
          frame={frame}
          fps={fps}
          delayFrames={16}
          title="Sessions with tests"
          value={`${testedCountAnimated}/${devlogSummary.sessionCount}`}
          detail="Build/test validation happened in-session"
          accentColor={colors.accent}
        />
        <MetricCard
          frame={frame}
          fps={fps}
          delayFrames={24}
          title="Codex actions captured"
          value={`${actionCountAnimated}`}
          detail="Bullets in 'What Codex Did'"
          accentColor={colors.accentHot}
        />
      </div>
    </AbsoluteFill>
  );
};

const TimelineScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const maxIndex = Math.max(1, devlogSessions.length - 1);
  const lineStart = 170;
  const lineWidth = 1580;
  const lineY = 500;
  const topCardY = 120;
  const bottomCardY = 580;
  const cardHeight = 250;
  const cardWidth = 246;

  const lineReveal = interpolate(
    frame,
    [0, 1.6 * fps],
    [0, lineWidth],
    clamp,
  );

  return (
    <AbsoluteFill
      style={{
        padding: "70px 90px",
        color: colors.text,
        fontFamily: displayFont,
      }}
    >
      <h2 style={{ margin: 0, fontSize: 56, letterSpacing: "-0.02em" }}>
        Session-by-Session Timeline
      </h2>
      <p style={{ margin: "12px 0 0", fontSize: 27, color: colors.muted }}>
        Each card is parsed from a real devlog entry.
      </p>
      <div
        style={{
          position: "absolute",
          left: lineStart,
          top: lineY,
          width: lineReveal,
          height: 2,
          background: colors.timeline,
          borderRadius: 2,
        }}
      />
      {devlogSessions.map((session, index) => {
        const reveal = spring({
          frame: frame - index * 10,
          fps,
          config: { damping: 200 },
        });
        const x = lineStart + (lineWidth * index) / maxIndex;
        const cardTop = index % 2 === 0 ? topCardY : bottomCardY;
        const connectorTop = index % 2 === 0 ? cardTop + cardHeight : lineY;
        const connectorHeight =
          index % 2 === 0 ? lineY - (cardTop + cardHeight) : cardTop - lineY;
        const timeSaved = session.timeSavedLabel ? session.timeSavedLabel : "n/a";
        const toolLabel =
          session.tools.length > 0
            ? truncate(session.tools.slice(0, 2).join(" + "), 30)
            : "n/a";

        return (
          <div key={session.id}>
            <div
              style={{
                position: "absolute",
                left: x - 2,
                top: connectorTop,
                width: 4,
                height: connectorHeight,
                background: "rgba(160, 217, 238, 0.35)",
                opacity: reveal,
              }}
            />
            <div
              style={{
                position: "absolute",
                left: x - 9,
                top: lineY - 9,
                width: 18,
                height: 18,
                borderRadius: 9,
                background: colors.accent,
                boxShadow: "0 0 22px rgba(46,217,196,0.5)",
                transform: `scale(${interpolate(reveal, [0, 1], [0.3, 1])})`,
              }}
            />
            <div
              style={{
                position: "absolute",
                left: x - cardWidth / 2,
                top: cardTop,
                width: cardWidth,
                height: cardHeight,
                borderRadius: 18,
                border: `1px solid ${colors.panelBorder}`,
                background: colors.panel,
                padding: "14px 14px 16px",
                display: "flex",
                flexDirection: "column",
                gap: 8,
                opacity: reveal,
                transform: `translateY(${interpolate(reveal, [0, 1], [18, 0])}px)`,
              }}
            >
              <div
                style={{
                  color: colors.accentWarm,
                  fontFamily: monoFont,
                  fontSize: 24,
                  letterSpacing: "0.03em",
                }}
              >
                {session.clockTime}
              </div>
              <div
                style={{
                  fontSize: 22,
                  lineHeight: 1.2,
                  fontWeight: 650,
                }}
              >
                {truncate(session.primaryGoal, 95)}
              </div>
              <div style={{ marginTop: "auto", fontSize: 18, color: colors.muted }}>
                Tools: {toolLabel}
              </div>
              <div style={{ fontSize: 18, color: colors.muted }}>
                Time saved: {timeSaved}
              </div>
              <div style={{ fontSize: 18, color: colors.muted }}>
                Tests: {session.hasTests ? "yes" : "none"}
              </div>
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

const rubricRows = [
  {
    title: "Impact (25%)",
    note: "Evidence of time saved + concrete deliverables.",
  },
  {
    title: "Codex App Story (25%)",
    note: "Logs show agents, tools, and cross-file implementation loops.",
  },
  {
    title: "Creative Skills Usage (25%)",
    note: "Skill-driven workflow: devlog + ideation + build/test skills.",
  },
  {
    title: "Demo and Pitch (25%)",
    note: "Narrative condensed into one clear 60-120 second flow.",
  },
];

const ImpactScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const chartHeight = 430;
  const barWidth = 110;
  const gap = 38;
  const chartStartX = 90;
  const chartBottom = 810;

  let maxMidpoint = 0;
  for (const session of devlogSessions) {
    const midpoint = getTimeSavedMidpoint(session);
    if (midpoint > maxMidpoint) {
      maxMidpoint = midpoint;
    }
  }

  return (
    <AbsoluteFill
      style={{
        padding: "74px 84px",
        color: colors.text,
        fontFamily: displayFont,
        display: "flex",
        flexDirection: "row",
        gap: 28,
      }}
    >
      <div
        style={{
          flex: 1.3,
          borderRadius: 22,
          border: `1px solid ${colors.panelBorder}`,
          background: colors.panel,
          position: "relative",
          overflow: "hidden",
        }}
      >
        <h2
          style={{
            margin: "26px 30px 4px",
            fontSize: 46,
            letterSpacing: "-0.02em",
          }}
        >
          Time Saved per Session
        </h2>
        <p style={{ margin: "0 30px", fontSize: 24, color: colors.muted }}>
          Midpoint of each session estimate (minutes)
        </p>
        <div
          style={{
            position: "absolute",
            left: 70,
            right: 60,
            top: chartBottom,
            height: 2,
            background: "rgba(160, 217, 238, 0.45)",
          }}
        />
        {devlogSessions.map((session, index) => {
          const midpoint = getTimeSavedMidpoint(session);
          const normalized = maxMidpoint > 0 ? midpoint / maxMidpoint : 0;
          const grow = spring({
            frame: frame - index * 8,
            fps,
            config: { damping: 190 },
          });
          const barHeight = chartHeight * normalized * grow;
          const x = chartStartX + index * (barWidth + gap);
          const color = session.hasTests ? colors.accent : colors.accentHot;

          return (
            <div key={session.id}>
              <div
                style={{
                  position: "absolute",
                  left: x,
                  top: chartBottom - barHeight,
                  width: barWidth,
                  height: barHeight,
                  borderRadius: "16px 16px 6px 6px",
                  background: `linear-gradient(180deg, ${color} 0%, rgba(4,40,58,1) 100%)`,
                }}
              />
              <div
                style={{
                  position: "absolute",
                  left: x,
                  width: barWidth,
                  top: chartBottom - barHeight - 38,
                  textAlign: "center",
                  fontSize: 24,
                  color,
                  fontFamily: monoFont,
                }}
              >
                {formatMinutesCompact(Math.round(midpoint))}
              </div>
              <div
                style={{
                  position: "absolute",
                  left: x - 8,
                  width: barWidth + 16,
                  top: chartBottom + 16,
                  textAlign: "center",
                  fontSize: 20,
                  color: colors.muted,
                  fontFamily: monoFont,
                }}
              >
                {session.clockTime}
              </div>
            </div>
          );
        })}
      </div>
      <div
        style={{
          flex: 1,
          borderRadius: 22,
          border: `1px solid ${colors.panelBorder}`,
          background: colors.panel,
          padding: "24px 28px",
          display: "flex",
          flexDirection: "column",
          gap: 12,
        }}
      >
        <h3 style={{ margin: "6px 0 0", fontSize: 42, lineHeight: 1.06 }}>
          Purpose of this cut
        </h3>
        <p style={{ margin: 0, fontSize: 24, color: colors.muted }}>
          Convert raw devlogs into a judging-aligned proof reel.
        </p>
        {rubricRows.map((row, index) => {
          const reveal = spring({
            frame: frame - 14 - index * 8,
            fps,
            config: { damping: 200 },
          });

          return (
            <div
              key={row.title}
              style={{
                borderRadius: 16,
                border: `1px solid ${colors.panelBorder}`,
                background: "rgba(7, 30, 43, 0.6)",
                padding: "12px 14px",
                opacity: reveal,
                transform: `translateY(${interpolate(reveal, [0, 1], [12, 0])}px)`,
              }}
            >
              <div style={{ fontSize: 24, color: colors.accentWarm, marginBottom: 2 }}>
                {row.title}
              </div>
              <div style={{ fontSize: 21, color: colors.muted, lineHeight: 1.25 }}>
                {row.note}
              </div>
            </div>
          );
        })}
        <div
          style={{
            marginTop: "auto",
            borderRadius: 14,
            background: "rgba(46, 217, 196, 0.15)",
            border: "1px solid rgba(46, 217, 196, 0.3)",
            padding: "12px 14px",
            fontSize: 23,
            lineHeight: 1.28,
          }}
        >
          Deadline check: submissions due {HACKATHON_DAY} at {DEADLINE}. This reel is
          designed for a crisp 60-120 second demo story.
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const HackathonDevlogComposition = () => {
  const { fps } = useVideoConfig();

  const introDuration = 5 * fps;
  const kpiDuration = 8 * fps;
  const timelineDuration = 11 * fps;
  const impactDuration = 12 * fps;

  return (
    <AbsoluteFill style={{ color: colors.text, fontFamily: displayFont }}>
      <Backdrop />
      <Sequence from={0} durationInFrames={introDuration} premountFor={fps}>
        <IntroScene />
      </Sequence>
      <Sequence
        from={introDuration}
        durationInFrames={kpiDuration}
        premountFor={fps}
      >
        <KpiScene />
      </Sequence>
      <Sequence
        from={introDuration + kpiDuration}
        durationInFrames={timelineDuration}
        premountFor={fps}
      >
        <TimelineScene />
      </Sequence>
      <Sequence
        from={introDuration + kpiDuration + timelineDuration}
        durationInFrames={impactDuration}
        premountFor={fps}
      >
        <ImpactScene />
      </Sequence>
    </AbsoluteFill>
  );
};
