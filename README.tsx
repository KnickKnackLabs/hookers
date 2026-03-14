/** @jsxImportSource jsx-md */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, resolve } from "path";

import {
  Heading, Paragraph, CodeBlock,
  Bold, Code, Link,
  Badge, Badges, Center, Section,
  Table, TableHead, TableRow, Cell,
  List, Item,
} from "readme/src/components";

// ── Dynamic data ─────────────────────────────────────────────

const REPO_DIR = resolve(import.meta.dirname);

// Extract commands from .mise/tasks/ (top-level only, skip directories)
const commands: { name: string; desc: string }[] = readdirSync(join(REPO_DIR, ".mise/tasks"))
  .filter((f) => {
    const full = join(REPO_DIR, ".mise/tasks", f);
    return statSync(full).isFile();
  })
  .map((f) => {
    const content = readFileSync(join(REPO_DIR, ".mise/tasks", f), "utf-8");
    const match = content.match(/#MISE description="(.+?)"/);
    return { name: f, desc: match?.[1] ?? "" };
  })
  .filter((c) => c.desc.length > 0)
  .sort((a, b) => a.name.localeCompare(b.name));

// Read catalog entries
const catalogDir = join(REPO_DIR, "catalog");
const catalogEntries = readdirSync(catalogDir)
  .filter((f) => f.endsWith(".json"))
  .map((f) => {
    const data = JSON.parse(readFileSync(join(catalogDir, f), "utf-8"));
    return { name: data.name, desc: data.description };
  })
  .sort((a, b) => a.name.localeCompare(b.name));

// Read bundled providers
const providerDir = join(REPO_DIR, "scripts/providers");
const providers = readdirSync(providerDir)
  .filter((f) => f.endsWith(".sh"))
  .map((f) => {
    const content = readFileSync(join(providerDir, f), "utf-8");
    const match = content.match(/^# Dashboard provider: (.+)$/m);
    return { name: f.replace(".sh", ""), desc: match?.[1] ?? "" };
  })
  .sort((a, b) => a.name.localeCompare(b.name));

// Count tests
const testDir = join(REPO_DIR, "test");
const testFiles = readdirSync(testDir).filter((f) => f.endsWith(".bats"));
const testCount = testFiles.reduce((sum, f) => {
  const content = readFileSync(join(testDir, f), "utf-8");
  return sum + (content.match(/@test /g)?.length ?? 0);
}, 0);

// ── README ───────────────────────────────────────────────────

const readme = (
  <>
    <Center>
      <Heading level={1}>hookers</Heading>

      <Paragraph>
        <Bold>Agent hooks infrastructure.</Bold>
      </Paragraph>

      <Paragraph>
        A catalog of hooks for Claude Code (and eventually other agent clients).{"\n"}
        Apply what you need. Skip what you don't.
      </Paragraph>

      <Badges>
        <Badge label="shell" value="bash" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="runtime" value="mise" color="7c3aed" href="https://mise.jdx.dev" />
        <Badge label="tests" value={`${testCount} passing`} color="brightgreen" />
        <Badge label="hooks" value={`${catalogEntries.length}`} color="blue" />
        <Badge label="License" value="MIT" color="blue" href="LICENSE" />
      </Badges>
    </Center>

    <Section title="Install">
      <CodeBlock lang="bash">{`shiv install hookers`}</CodeBlock>
    </Section>

    <Section title="Quick start">
      <CodeBlock lang="bash">{`# See available hooks
hookers catalog

# Apply hooks to your Claude Code settings
hookers apply session-id dashboard

# Apply all hooks
hookers apply

# Remove a hook
hookers unapply dashboard

# See what's installed
hookers list`}</CodeBlock>
    </Section>

    <Section title="Hook catalog">
      <Paragraph>
        Each hook lives as a self-describing JSON file in <Code>catalog/</Code>.
        Apply selectively — only install what you need.
      </Paragraph>

      <Table>
        <TableHead>
          <Cell>Hook</Cell>
          <Cell>Description</Cell>
        </TableHead>
        {catalogEntries.map((entry) => (
          <TableRow>
            <Cell><Code>{entry.name}</Code></Cell>
            <Cell>{entry.desc}</Cell>
          </TableRow>
        ))}
      </Table>
    </Section>

    <Section title="Dashboard">
      <Paragraph>
        The <Code>dashboard</Code> hook injects a compact status line into your
        agent's context on every prompt. Configure what data to show
        via <Code>~/.config/hookers/dashboard.json</Code>:
      </Paragraph>

      <CodeBlock lang="json">{readFileSync(join(REPO_DIR, "examples/dashboard.json"), "utf-8").trim()}</CodeBlock>

      <Paragraph>
        Output looks like:
      </Paragraph>

      <CodeBlock>{`[dashboard] mail: 84 | branch: main | gh-token: 5d | dirty: 3 | time: 14:30 UTC`}</CodeBlock>

      <Paragraph>
        Providers run in parallel with per-item timeouts. Items that produce no
        output are silently skipped. See{" "}
        <Link href="https://github.com/KnickKnackLabs/escort">escort</Link> for
        richer providers designed for agent workflows.
      </Paragraph>
    </Section>

    <Section title="Bundled providers">
      <Table>
        <TableHead>
          <Cell>Provider</Cell>
          <Cell>Description</Cell>
        </TableHead>
        {providers.map((p) => (
          <TableRow>
            <Cell><Code>{`hookers provider ${p.name}`}</Code></Cell>
            <Cell>{p.desc}</Cell>
          </TableRow>
        ))}
      </Table>
    </Section>

    <Section title="How it works">
      <Paragraph>
        Hooks are identified by a bash comment marker (<Code>{"# hookers:<name>"}</Code>)
        embedded in the command. This enables:
      </Paragraph>

      <List>
        <Item><Bold>Idempotent apply</Bold> — re-applying detects unchanged hooks and skips them</Item>
        <Item><Bold>Clean updates</Bold> — changed hooks are replaced, not duplicated</Item>
        <Item><Bold>Reliable unapply</Bold> — removal by catalog name, not by exact command string</Item>
      </List>

      <Paragraph>
        Hooks are written to Claude Code's <Code>settings.json</Code> (user scope by
        default). Use <Code>--scope project</Code> or <Code>--scope local</Code> for
        per-project hooks.
      </Paragraph>
    </Section>

    <Section title="Commands">
      <Table>
        <TableHead>
          <Cell>Command</Cell>
          <Cell>Description</Cell>
        </TableHead>
        {commands.map((cmd) => (
          <TableRow>
            <Cell><Code>{`hookers ${cmd.name}`}</Code></Cell>
            <Cell>{cmd.desc}</Cell>
          </TableRow>
        ))}
      </Table>
    </Section>

    <Section title="Development">
      <CodeBlock lang="bash">{`git clone https://github.com/KnickKnackLabs/hookers.git
cd hookers && mise trust && mise install
mise run test`}</CodeBlock>

      <Paragraph>
        Tests use <Link href="https://github.com/bats-core/bats-core">BATS</Link> — {testCount} tests
        across {testFiles.length} suites covering {testFiles.map((f) => f.replace(".bats", "")).join(", ")}.
      </Paragraph>
    </Section>

    <Center>
      <Section title="License">
        <Paragraph>MIT</Paragraph>
      </Section>

      <Paragraph>
        {"This README was created using "}
        <Link href="https://github.com/KnickKnackLabs/readme">readme</Link>.
      </Paragraph>
    </Center>
  </>
);

console.log(readme);
