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

const normalizeToolName = (tool: string) => {
  const lower = tool.toLowerCase();
  if (lower.includes("xcode mcp")) {
    return "Xcode MCP";
  }
  if (lower.includes("swift test")) {
    return "swift test";
  }
  if (lower.includes("apply_patch")) {
    return "apply_patch";
  }
  if (lower.includes("terminal")) {
    return "terminal";
  }

  return tool;
};

const formatToolsCompact = (tools: string[]) => {
  if (tools.length === 0) {
    return "n/a";
  }

  const primary = normalizeToolName(tools[0]);
  if (tools.length === 1) {
    return primary;
  }

  return `${primary} +${tools.length - 1}`;
};

const formatTimeSavedCompact = (session: DevlogSession) => {
  if (session.timeSavedRangeMinutes) {
    return formatRangeCompact(session.timeSavedRangeMinutes);
  }

  if (session.timeSavedLabel) {
    return session.timeSavedLabel.replace(/\.$/, "");
  }

  return "n/a";
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

  const markerCount = devlogSessions.length + 1;
  const maxIndex = Math.max(1, markerCount - 1);
  const lineStart = 130;
  const lineEnd = 1790;
  const lineWidth = lineEnd - lineStart;
  const lineY = 610;
  const topCardY = 230;
  const bottomCardY = 750;
  const cardHeight = 228;
  const slotWidth = lineWidth / maxIndex;
  const cardWidth = Math.max(128, Math.min(228, slotWidth - 22));
  const goalFontSize = cardWidth <= 150 ? 16 : 18;
  const metadataFontSize = cardWidth <= 150 ? 13 : 14;
  const deadlineIndex = markerCount - 1;
  const deadlineX = lineStart + (lineWidth * deadlineIndex) / maxIndex;
  const deadlineReveal = spring({
    frame: frame - devlogSessions.length * 10,
    fps,
    config: { damping: 200 },
  });

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
        const timeSaved = formatTimeSavedCompact(session);
        const toolLabel = truncate(formatToolsCompact(session.tools), 20);
        const goalMaxChars = Math.max(42, Math.round(cardWidth * 0.34));

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
                padding: "12px 12px 14px",
                display: "flex",
                flexDirection: "column",
                gap: 6,
                opacity: reveal,
                transform: `translateY(${interpolate(reveal, [0, 1], [18, 0])}px)`,
              }}
            >
              <div
                style={{
                  color: colors.accentWarm,
                  fontFamily: monoFont,
                  fontSize: 22,
                  letterSpacing: "0.03em",
                }}
              >
                {session.clockTime}
              </div>
              <div
                style={{
                  fontSize: goalFontSize,
                  lineHeight: 1.2,
                  fontWeight: 650,
                  minHeight: goalFontSize * 4.2,
                  display: "-webkit-box",
                  WebkitLineClamp: 4,
                  WebkitBoxOrient: "vertical",
                  overflow: "hidden",
                }}
              >
                {truncate(session.primaryGoal, goalMaxChars)}
              </div>
              <div
                style={{
                  marginTop: "auto",
                  fontSize: metadataFontSize,
                  color: colors.muted,
                  whiteSpace: "nowrap",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                }}
              >
                Tools: {toolLabel}
              </div>
              <div
                style={{
                  fontSize: metadataFontSize,
                  color: colors.muted,
                  whiteSpace: "nowrap",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                }}
              >
                Time saved: {timeSaved}
              </div>
              <div
                style={{
                  fontSize: metadataFontSize,
                  color: colors.muted,
                  whiteSpace: "nowrap",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                }}
              >
                Tests: {session.hasTests ? "yes" : "none"}
              </div>
            </div>
          </div>
        );
      })}
      <div
        style={{
          position: "absolute",
          left: deadlineX - 2,
          top: lineY - 62,
          width: 4,
          height: 62,
          background: "rgba(255, 190, 89, 0.42)",
          opacity: deadlineReveal,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: deadlineX - 11,
          top: lineY - 11,
          width: 22,
          height: 22,
          borderRadius: 11,
          background: colors.accentWarm,
          boxShadow: "0 0 26px rgba(255,190,89,0.55)",
          transform: `scale(${interpolate(deadlineReveal, [0, 1], [0.3, 1])})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: deadlineX - 96,
          top: lineY - 124,
          width: 192,
          borderRadius: 12,
          border: `1px solid rgba(255, 190, 89, 0.38)`,
          background: "rgba(36, 25, 9, 0.7)",
          color: colors.accentWarm,
          textAlign: "center",
          padding: "9px 10px",
          fontSize: 22,
          fontFamily: monoFont,
          letterSpacing: "0.02em",
          opacity: deadlineReveal,
          transform: `translateY(${interpolate(deadlineReveal, [0, 1], [10, 0])}px)`,
        }}
      >
        4:00 PM Deadline
      </div>
    </AbsoluteFill>
  );
};

type SkillGroup = {
  title: string;
  subtitle: string;
  skills: string[];
  accent: string;
};

const skillGroups: SkillGroup[] = [
  {
    title: "Build Tools",
    subtitle: "Compile, project edits, and simulator-driven checks.",
    skills: ["xcodebuild", "xcodeproj-edit", "sim-control"],
    accent: colors.accent,
  },
  {
    title: "Hackathon Helpers",
    subtitle: "Idea shaping, judging alignment, and submission packaging.",
    skills: ["codex-hackathon-ideation", "codex-hackathon-submission"],
    accent: colors.accentWarm,
  },
  {
    title: "Codex Devlog Visualization",
    subtitle: "Session logging and storytelling through motion.",
    skills: ["codex-devlog", "remotion"],
    accent: colors.accentHot,
  },
];

const automationHighlights = [
  "Codex App -> Automations",
  "Recurring task: add Codex devlog entry",
  "Interval schedule: runs regularly during hackathon build loops",
  "Output target: codex-log/YYYY-MM-DD_HHMM-<slug>.md",
];

const SkillsScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const automationReveal = spring({
    frame: frame - 28,
    fps,
    config: { damping: 200 },
  });

  return (
    <AbsoluteFill
      style={{
        padding: "88px 100px",
        color: colors.text,
        fontFamily: displayFont,
      }}
    >
      <h2 style={{ margin: 0, fontSize: 64, letterSpacing: "-0.02em" }}>
        Codex Skills Map
      </h2>
      <p style={{ margin: "12px 0 0", fontSize: 27, color: colors.muted }}>
        Grouped by how they support this hackathon build and demo flow.
      </p>
      <div
        style={{
          marginTop: 34,
          display: "grid",
          gridTemplateColumns: "1fr 1fr 1fr",
          gap: 24,
          flex: 1,
        }}
      >
        {skillGroups.map((group, index) => {
          const reveal = spring({
            frame: frame - index * 10,
            fps,
            config: { damping: 200 },
          });

          return (
            <div
              key={group.title}
              style={{
                borderRadius: 22,
                border: `1px solid ${colors.panelBorder}`,
                background: colors.panel,
                padding: "22px 22px 24px",
                display: "flex",
                flexDirection: "column",
                opacity: reveal,
                transform: `translateY(${interpolate(reveal, [0, 1], [20, 0])}px)`,
              }}
            >
              <div
                style={{
                  fontSize: 31,
                  lineHeight: 1.05,
                  fontWeight: 700,
                  color: group.accent,
                }}
              >
                {group.title}
              </div>
              <div
                style={{
                  marginTop: 10,
                  fontSize: 22,
                  lineHeight: 1.3,
                  color: colors.muted,
                }}
              >
                {group.subtitle}
              </div>
              <div
                style={{
                  marginTop: 22,
                  display: "flex",
                  flexDirection: "column",
                  gap: 10,
                }}
              >
                {group.skills.map((skill, skillIndex) => {
                  const chipReveal = spring({
                    frame: frame - index * 10 - skillIndex * 5 - 4,
                    fps,
                    config: { damping: 200 },
                  });

                  return (
                    <div
                      key={skill}
                      style={{
                        borderRadius: 12,
                        border: `1px solid ${colors.panelBorder}`,
                        background: "rgba(8, 32, 46, 0.72)",
                        color: colors.text,
                        padding: "10px 12px",
                        fontSize: 23,
                        fontFamily: monoFont,
                        letterSpacing: "0.01em",
                        opacity: chipReveal,
                        transform: `translateX(${interpolate(chipReveal, [0, 1], [-10, 0])}px)`,
                      }}
                    >
                      {skill}
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
      <div
        style={{
          marginTop: 18,
          borderRadius: 18,
          border: `1px solid rgba(46, 217, 196, 0.35)`,
          background: "rgba(9, 37, 45, 0.78)",
          padding: "16px 18px",
          display: "flex",
          alignItems: "center",
          gap: 18,
          opacity: automationReveal,
          transform: `translateY(${interpolate(automationReveal, [0, 1], [14, 0])}px)`,
        }}
      >
        <div
          style={{
            borderRadius: 11,
            border: "1px solid rgba(46, 217, 196, 0.35)",
            background: "rgba(46, 217, 196, 0.12)",
            color: colors.accent,
            fontSize: 18,
            letterSpacing: "0.05em",
            textTransform: "uppercase",
            padding: "7px 10px",
            whiteSpace: "nowrap",
          }}
        >
          Codex App Automations
        </div>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: "8px 16px",
            width: "100%",
          }}
        >
          {automationHighlights.map((item, index) => {
            const itemReveal = spring({
              frame: frame - 32 - index * 4,
              fps,
              config: { damping: 200 },
            });

            return (
              <div
                key={item}
                style={{
                  color: colors.muted,
                  fontSize: 19,
                  lineHeight: 1.25,
                  opacity: itemReveal,
                  transform: `translateX(${interpolate(itemReveal, [0, 1], [-8, 0])}px)`,
                }}
              >
                {item}
              </div>
            );
          })}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const mcpLoopSteps = [
  {
    title: "Edit Workspace Files",
    detail: "Patch Swift sources, fixtures, and tests inside the Codex App.",
  },
  {
    title: "xcode MCP BuildProject",
    detail: "Compile after each patch to catch regressions immediately.",
  },
  {
    title: "xcode MCP RunSomeTests",
    detail: "Run focused tests for the changed feature surface.",
  },
  {
    title: "xcode MCP RunAllTests",
    detail: "Checkpoint with wider test coverage before handoff.",
  },
  {
    title: "xcode MCP XcodeListNavigatorIssues",
    detail: "Inspect remaining diagnostics and close the loop.",
  },
];

const mcpActivityLines = [
  "Edited ChatStreamClient.swift +106 -7",
  "Called xcode MCP BuildProject tool",
  "Called xcode MCP RunSomeTests tool",
  "Called xcode MCP XcodeListNavigatorIssues tool",
  "Edited RenderChatUITests.swift +17 -8",
  "Called xcode MCP RunAllTests tool",
];

const TechnicalFlowScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const sceneReveal = spring({
    frame,
    fps,
    config: { damping: 200 },
  });

  return (
    <AbsoluteFill
      style={{
        padding: "84px 94px",
        color: colors.text,
        fontFamily: displayFont,
      }}
    >
      <h2
        style={{
          margin: 0,
          fontSize: 62,
          letterSpacing: "-0.02em",
          opacity: sceneReveal,
          transform: `translateY(${interpolate(sceneReveal, [0, 1], [12, 0])}px)`,
        }}
      >
        Codex App Technical Flow
      </h2>
      <p
        style={{
          margin: "12px 0 0",
          fontSize: 27,
          color: colors.muted,
          maxWidth: 1400,
          opacity: sceneReveal,
        }}
      >
        Built exclusively in the Codex App, using the Xcode 26.3 MCP server as the
        core build-and-test feedback loop.
      </p>
      <div
        style={{
          marginTop: 20,
          display: "flex",
          gap: 10,
        }}
      >
        {["Codex App only", "Xcode MCP 26.3", "Build/Test loop"].map(
          (badge, index) => {
            const badgeReveal = spring({
              frame: frame - index * 5,
              fps,
              config: { damping: 200 },
            });

            return (
              <div
                key={badge}
                style={{
                  borderRadius: 999,
                  border: `1px solid ${colors.panelBorder}`,
                  background: "rgba(8, 32, 46, 0.76)",
                  color: colors.accent,
                  padding: "8px 13px",
                  fontSize: 19,
                  letterSpacing: "0.04em",
                  textTransform: "uppercase",
                  opacity: badgeReveal,
                  transform: `translateY(${interpolate(badgeReveal, [0, 1], [8, 0])}px)`,
                }}
              >
                {badge}
              </div>
            );
          },
        )}
      </div>
      <div
        style={{
          marginTop: 22,
          display: "grid",
          gridTemplateColumns: "1.05fr 0.95fr",
          gap: 22,
          flex: 1,
        }}
      >
        <div
          style={{
            borderRadius: 22,
            border: `1px solid ${colors.panelBorder}`,
            background: colors.panel,
            padding: "18px 20px 20px",
          }}
        >
          <div
            style={{
              fontSize: 25,
              color: colors.accentWarm,
              textTransform: "uppercase",
              letterSpacing: "0.05em",
              marginBottom: 12,
            }}
          >
            Loop Steps
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {mcpLoopSteps.map((step, index) => {
              const stepReveal = spring({
                frame: frame - 6 - index * 6,
                fps,
                config: { damping: 200 },
              });

              return (
                <div
                  key={step.title}
                  style={{
                    borderRadius: 14,
                    border: `1px solid ${colors.panelBorder}`,
                    background: "rgba(8, 32, 46, 0.66)",
                    padding: "10px 12px",
                    display: "grid",
                    gridTemplateColumns: "38px 1fr",
                    gap: 10,
                    opacity: stepReveal,
                    transform: `translateX(${interpolate(stepReveal, [0, 1], [-10, 0])}px)`,
                  }}
                >
                  <div
                    style={{
                      width: 36,
                      height: 36,
                      borderRadius: 18,
                      border: `1px solid ${colors.panelBorder}`,
                      background: "rgba(46, 217, 196, 0.14)",
                      color: colors.accent,
                      fontSize: 19,
                      fontFamily: monoFont,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                  >
                    {index + 1}
                  </div>
                  <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                    <div style={{ fontSize: 25, lineHeight: 1.12, fontWeight: 650 }}>
                      {step.title}
                    </div>
                    <div style={{ fontSize: 20, lineHeight: 1.28, color: colors.muted }}>
                      {step.detail}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
        <div
          style={{
            borderRadius: 22,
            border: `1px solid ${colors.panelBorder}`,
            background: colors.panel,
            padding: "18px 20px 20px",
            display: "flex",
            flexDirection: "column",
          }}
        >
          <div
            style={{
              fontSize: 25,
              color: colors.accentWarm,
              textTransform: "uppercase",
              letterSpacing: "0.05em",
              marginBottom: 10,
            }}
          >
            Activity Stream
          </div>
          <div
            style={{
              borderRadius: 16,
              border: `1px solid ${colors.panelBorder}`,
              background: "rgba(3, 16, 22, 0.82)",
              padding: "12px 14px",
              display: "flex",
              flexDirection: "column",
              gap: 8,
              flex: 1,
              overflow: "hidden",
            }}
          >
            {mcpActivityLines.map((line, index) => {
              const lineReveal = spring({
                frame: frame - 12 - index * 4,
                fps,
                config: { damping: 200 },
              });

              return (
                <div
                  key={line}
                  style={{
                    fontSize: 21,
                    lineHeight: 1.25,
                    color: colors.muted,
                    fontFamily: monoFont,
                    whiteSpace: "nowrap",
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                    opacity: lineReveal,
                    transform: `translateX(${interpolate(lineReveal, [0, 1], [-8, 0])}px)`,
                  }}
                >
                  {line}
                </div>
              );
            })}
          </div>
          <div
            style={{
              marginTop: 12,
              borderRadius: 13,
              border: "1px solid rgba(46, 217, 196, 0.35)",
              background: "rgba(46, 217, 196, 0.14)",
              padding: "10px 12px",
              fontSize: 21,
              lineHeight: 1.3,
            }}
          >
            Tight compile/test/diagnostic cycles run inside Codex App without leaving the
            MCP toolchain.
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};

const ChallengesScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const latestRecoverySession = [...devlogSessions]
    .reverse()
    .find((session) => {
      const summary = session.challengeSummary?.toLowerCase() ?? "";
      const goal = session.primaryGoal.toLowerCase();
      return (
        summary.includes("rollback") ||
        summary.includes("revert") ||
        goal.includes("rollback") ||
        goal.includes("revert")
      );
    });
  const latestSession = latestRecoverySession ?? devlogSessions.at(-1);
  const recentChallenges = [...devlogSessions]
    .filter((session) => session.challengeSummary !== null)
    .slice(-6)
    .reverse();

  const latestGoal = latestSession
    ? truncate(latestSession.primaryGoal, 170)
    : "No recent challenge log available.";
  const latestDecision = latestSession?.humanDecisions
    ? truncate(latestSession.humanDecisions, 140)
    : "n/a";
  const latestBottleneck = latestSession?.bottlenecksRemoved
    ? truncate(latestSession.bottlenecksRemoved, 140)
    : "n/a";
  const manualUiChallenge =
    "Native SwiftUI UI/UX polish still needs hands-on manual intervention.";
  const manualUiTradeoff =
    "That is intentional for opinionated product quality, but it slows iteration throughput.";

  return (
    <AbsoluteFill
      style={{
        padding: "84px 92px",
        color: colors.text,
        fontFamily: displayFont,
      }}
    >
      <h2 style={{ margin: 0, fontSize: 62, letterSpacing: "-0.02em" }}>
        Challenges Encountered
      </h2>
      <p style={{ margin: "12px 0 0", fontSize: 27, color: colors.muted }}>
        Captured from devlogs, including the latest rollback/recovery note that
        documents how behavior was restored.
      </p>
      <div
        style={{
          marginTop: 26,
          display: "grid",
          gridTemplateColumns: "1.05fr 0.95fr",
          gap: 22,
          flex: 1,
        }}
      >
        <div
          style={{
            borderRadius: 22,
            border: `1px solid ${colors.panelBorder}`,
            background: colors.panel,
            padding: "20px 22px",
            display: "flex",
            flexDirection: "column",
            gap: 12,
          }}
        >
          <div
            style={{
              display: "inline-flex",
              alignSelf: "flex-start",
              borderRadius: 999,
              border: "1px solid rgba(255, 190, 89, 0.45)",
              background: "rgba(255, 190, 89, 0.15)",
              color: colors.accentWarm,
              fontSize: 18,
              letterSpacing: "0.05em",
              textTransform: "uppercase",
              padding: "7px 11px",
            }}
          >
            Latest Recovery Action
          </div>
          <div
            style={{
              borderRadius: 16,
              border: `1px solid ${colors.panelBorder}`,
              background: "rgba(8, 32, 46, 0.68)",
              padding: "12px 14px",
            }}
          >
            <div
              style={{
                fontFamily: monoFont,
                fontSize: 22,
                color: colors.accentWarm,
                marginBottom: 6,
              }}
            >
              {latestSession?.clockTime ?? "n/a"} PST
            </div>
            <div
              style={{
                fontSize: 30,
                lineHeight: 1.12,
                fontWeight: 700,
              }}
            >
              {latestSession?.challengeSummary ?? "No challenge summary available."}
            </div>
          </div>
          <div
            style={{
              borderRadius: 14,
              border: `1px solid ${colors.panelBorder}`,
              background: "rgba(8, 32, 46, 0.6)",
              padding: "12px 14px",
              display: "flex",
              flexDirection: "column",
              gap: 8,
            }}
          >
            {[
              `Goal: ${latestGoal}`,
              `Bottleneck removed: ${latestBottleneck}`,
              `Human decision: ${latestDecision}`,
            ].map((line, index) => {
              const reveal = spring({
                frame: frame - 8 - index * 5,
                fps,
                config: { damping: 200 },
              });

              return (
                <div
                  key={line}
                  style={{
                    fontSize: 22,
                    lineHeight: 1.28,
                    color: colors.muted,
                    opacity: reveal,
                    transform: `translateX(${interpolate(reveal, [0, 1], [-10, 0])}px)`,
                  }}
                >
                  {line}
                </div>
              );
            })}
          </div>
          <div
            style={{
              borderRadius: 14,
              border: "1px solid rgba(255, 122, 93, 0.32)",
              background: "rgba(43, 19, 14, 0.62)",
              padding: "12px 14px",
              display: "flex",
              flexDirection: "column",
              gap: 6,
            }}
          >
            <div
              style={{
                fontSize: 18,
                letterSpacing: "0.05em",
                textTransform: "uppercase",
                color: colors.accentHot,
              }}
            >
              Ongoing UI/UX Constraint
            </div>
            <div style={{ fontSize: 22, lineHeight: 1.25 }}>{manualUiChallenge}</div>
            <div style={{ fontSize: 20, lineHeight: 1.3, color: colors.muted }}>
              {manualUiTradeoff}
            </div>
          </div>
        </div>
        <div
          style={{
            borderRadius: 22,
            border: `1px solid ${colors.panelBorder}`,
            background: colors.panel,
            padding: "18px 20px",
            display: "flex",
            flexDirection: "column",
            gap: 10,
          }}
        >
          <div
            style={{
              fontSize: 24,
              color: colors.accentWarm,
              letterSpacing: "0.05em",
              textTransform: "uppercase",
            }}
          >
            Recent Challenge Stream
          </div>
          <div
            style={{
              borderRadius: 14,
              border: `1px solid ${colors.panelBorder}`,
              background: "rgba(3, 16, 22, 0.82)",
              padding: "10px 12px",
              display: "flex",
              flexDirection: "column",
              gap: 8,
              flex: 1,
              overflow: "hidden",
            }}
          >
            {recentChallenges.map((session, index) => {
              const reveal = spring({
                frame: frame - 12 - index * 4,
                fps,
                config: { damping: 200 },
              });
              const line = session.challengeSummary ?? session.primaryGoal;

              return (
                <div
                  key={session.id}
                  style={{
                    borderRadius: 11,
                    border: `1px solid ${colors.panelBorder}`,
                    background: "rgba(8, 32, 46, 0.64)",
                    padding: "8px 10px",
                    display: "grid",
                    gridTemplateColumns: "78px 1fr",
                    gap: 10,
                    opacity: reveal,
                    transform: `translateY(${interpolate(reveal, [0, 1], [8, 0])}px)`,
                  }}
                >
                  <div
                    style={{
                      fontFamily: monoFont,
                      fontSize: 20,
                      color: colors.accent,
                    }}
                  >
                    {session.clockTime}
                  </div>
                  <div
                    style={{
                      fontSize: 20,
                      lineHeight: 1.25,
                      color: colors.muted,
                      display: "-webkit-box",
                      WebkitLineClamp: 2,
                      WebkitBoxOrient: "vertical",
                      overflow: "hidden",
                    }}
                  >
                    {line}
                  </div>
                </div>
              );
            })}
          </div>
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "1fr 1fr",
              gap: 10,
            }}
          >
            <div
              style={{
                borderRadius: 11,
                border: `1px solid ${colors.panelBorder}`,
                background: "rgba(8, 32, 46, 0.64)",
                padding: "8px 10px",
                fontSize: 20,
                color: colors.muted,
              }}
            >
              Challenge entries: {devlogSummary.challengeSessionCount}
            </div>
            <div
              style={{
                borderRadius: 11,
                border: `1px solid ${colors.panelBorder}`,
                background: "rgba(8, 32, 46, 0.64)",
                padding: "8px 10px",
                fontSize: 20,
                color: colors.muted,
              }}
            >
              Latest at {devlogSummary.lastSession} PT
            </div>
          </div>
        </div>
      </div>
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
  const skillsDuration = 7 * fps;
  const techFlowDuration = 8 * fps;
  const challengesDuration = 8 * fps;
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
        durationInFrames={skillsDuration}
        premountFor={fps}
      >
        <SkillsScene />
      </Sequence>
      <Sequence
        from={introDuration + skillsDuration}
        durationInFrames={techFlowDuration}
        premountFor={fps}
      >
        <TechnicalFlowScene />
      </Sequence>
      <Sequence
        from={introDuration + skillsDuration + techFlowDuration}
        durationInFrames={challengesDuration}
        premountFor={fps}
      >
        <ChallengesScene />
      </Sequence>
      <Sequence
        from={introDuration + skillsDuration + techFlowDuration + challengesDuration}
        durationInFrames={kpiDuration}
        premountFor={fps}
      >
        <KpiScene />
      </Sequence>
      <Sequence
        from={
          introDuration +
          skillsDuration +
          techFlowDuration +
          challengesDuration +
          kpiDuration
        }
        durationInFrames={timelineDuration}
        premountFor={fps}
      >
        <TimelineScene />
      </Sequence>
      <Sequence
        from={
          introDuration +
          skillsDuration +
          techFlowDuration +
          challengesDuration +
          kpiDuration +
          timelineDuration
        }
        durationInFrames={impactDuration}
        premountFor={fps}
      >
        <ImpactScene />
      </Sequence>
    </AbsoluteFill>
  );
};
