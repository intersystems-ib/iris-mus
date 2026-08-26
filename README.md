**# IRIS Mus Project Documentation**

![image](https://github.com/intersystems-ib/iris-mus/blob/main/images/iris_mus.png)

**## 1. Project overview**

****IRIS Mus**** is a full-stack application that implements the Spanish card game ****Mus**** using three main technical layers: an ****InterSystems IRIS backend****, a ****React frontend****, and an ****LLM-based AI player layer****.

The project is designed as a Docker-first application. The complete runtime stack is deployed with Docker Compose and includes the backend, the Web Gateway, the production frontend, and a local LLM server. A user can access the application from the browser without starting the frontend manually.

At a high level, the project demonstrates how InterSystems IRIS can coordinate transactional application logic, game state, tournament management, and AI-assisted decisions while exposing a modern web interface.

---

**## 2. Main parts of the project**

**### 2.1 InterSystems IRIS backend**

The backend is the authoritative layer of the application. It owns the game state, validates player actions, resolves Mus rules, manages tournaments, and coordinates interactions with AI players.

Its responsibilities include:

- Creating games and tournaments.

- Loading and storing game state.

- Managing hands, phases, turns, actions, discards, scores, winners, and tournament progress.

- Validating whether a human or AI action is legal.

- Resolving the effect of each action.

- Coordinating autonomous agent decisions.

- Returning normalized state snapshots to the frontend.

The backend is implemented with InterSystems IRIS and ObjectScript. It uses an interoperability production to separate the main responsibilities into coordinators, rule handling, persistence operations, AI integration, and message contracts.

This separation is important because the application has several different flows: quick games, human actions, AI actions, tournament creation, table simulation, and tournament completion. Each flow is routed through the backend so the same rule and persistence model is consistently applied.

**### 2.2 React frontend**

The frontend provides the browser-based user interface for the game and tournament experience.

It allows users to:

- Create and start games.

- Create tournaments.

- Generate tournament teams with AI assistance.

- Browse tournament lists and details.

- Start tournament tables.

- Play Mus against AI players.

- See cards, player seats, actions, scores, hand results, and winners.

- Send human actions such as passing, betting, accepting, refusing, or declaring an ordago.

The frontend is built with React and TypeScript. It uses a modern single-page application structure with client-side routing, server-state management, and a centralized API client.

In the current deployment architecture, the frontend is not run manually with a development server. It is built into static production assets and served by Nginx inside the `mus-frontend` Docker container. The browser accesses the UI through `http://localhost:5173`.

The frontend communicates with the backend through relative API paths. Those requests are handled by the frontend Nginx server, which proxies API calls to the Web Gateway service inside the Docker network.

**### 2.3 LLM and AI player layer

The LLM layer gives the project autonomous AI players and AI-assisted content generation.

The LLM is used to recommend decisions such as:

- Whether an AI player wants Mus or cuts Mus.
- Which cards an AI player should discard.
- Which betting action an AI player should take.
- How an AI player should respond to a pending bet.
- What tournament name, team names, and player names should be suggested.
- How to simulate tables where all players are agents.

Gameplay decisions now use a two-stage AI flow:

1. **Evaluation stage**: an AI Hub agent is created with a narrowly filtered ToolSet and is instructed to call exactly one evaluation tool, such as `EvaluatePlayStrength` or `EvaluateDiscardHandValue`.
2. **Decision stage**: a new agent/session is created **without tools**. It receives the raw tool result plus compact strategic context and chooses one exact `FINAL|...` candidate line.

The evaluation session is configured with `max_iterations=1`, so only one tool call is allowed for the turn. This avoids repeated tool calls and makes the local llama.cpp integration more predictable.

The LLM does not own the rules of the game. The backend remains authoritative for game state, legal actions, mechanical validation, score resolution, and application of actions. The model is responsible for choosing the strategic recommendation from the context made available to it.

Tool output is treated as a strategic signal, not as a final action. The backend parses the model's compact transport response and applies only mechanically legal actions through the normal rule flow.

This design also separates tool execution from final structured output, which is important for local models whose native tool-call parser can otherwise confuse a final JSON response with another tool invocation.

### 2.4 Docker deployment layer**

The project is deployed with Docker Compose. The current architecture includes four services:

- ****iris-mus****: runs the InterSystems IRIS backend.

- ****webgateway****: exposes the backend API through the InterSystems Web Gateway.

- ****mus-frontend****: serves the production React application through Nginx.

- ****llama****: runs a local llama.cpp model server for LLM inference. The model Qwen3-4B-Instruct-2507-Q4_K_M.gguf IS NOT INCLUDED, please, download it from [here](https://huggingface.co/alphaduriendur/Qwen3-4B-Instruct-2507-Q4_K_M-GGUF)

This architecture allows the complete application to run locally as a coordinated stack. The user opens the frontend in the browser, the frontend routes API calls to the Web Gateway, the Web Gateway connects to IRIS, and IRIS calls the local model server whenever an AI decision is needed.

---

**## 3. Deployment architecture**

**### 3.1 Runtime services**

**#### iris-mus**

The `iris-mus` service runs the InterSystems IRIS backend. It contains the ObjectScript classes, backend production, rule logic, persistence logic, and AI coordination code.

This service is responsible for the application state and business logic. It is the source of truth for games, hands, actions, scores, tournaments, and winners.

It also uses durable storage so that backend data can persist outside the container lifecycle.

**##### AI Hub Container**

1\. Download an AI Hub container from the [Early Access Program Portal](https://evaluation.intersystems.com/Eval/early-access/AIHub). The docker-containers end with `docker.tar.gz`, ensure you choose the version suitable for your operating system (arm64 for macOS).

OR 

1\. Copy AI Hub Container from your Flash Drive

2\. Load the image with: 

    ```bash

    docker load -i /path/to/iris-community-2026.2.0AI.162.0-docker.tar.gz

    ```

    Once it's complete you should see `Loaded image: docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.2.0AI.162.0` (if not you can use `docker images` to find the image name). 

3\. Change the Image name in the [Dockerfile](./Dockerfile) to match your version and operating system (image name printed above).

**#### webgateway**

The `webgateway` service runs the InterSystems Web Gateway. It acts as the HTTP access layer between external clients and the IRIS backend.

The frontend does not call IRIS directly. Instead, requests are routed through the Web Gateway, which forwards them to the correct IRIS backend services.

From the host machine, the Web Gateway is exposed on port `8080` for HTTP and `8443` for HTTPS. From inside the Docker network, other containers address it by its service name, `webgateway`.

**#### mus-frontend**

The `mus-frontend` service builds and serves the React application.

Its image has two conceptual stages:

- A build stage that compiles the React and TypeScript application into static production assets.

- A runtime stage that serves those assets with Nginx.

This service exposes the browser UI on `http://localhost:5173`.

It also acts as a reverse proxy for backend API requests. When the browser calls `/api/mus/...`, the frontend container forwards those requests to the internal `webgateway` service. This means the browser only needs to interact with the frontend address during normal use.

**#### llama**

The `llama` service runs a local OpenAI-compatible llama.cpp server.

It loads a local GGUF model from the project model directory and exposes an inference endpoint that the backend can use for chat-completion-style requests.

The current deployment is configured for GPU acceleration. If the host machine does not have a compatible NVIDIA GPU, this service may need to be adapted to a CPU-based model server or replaced with a cloud-hosted model endpoint.

**### 3.2 Request flow**

The normal runtime flow is:

1\. The user opens the application at `http://localhost:5173`.

2\. The browser receives the React application from the `mus-frontend` container.

3\. The frontend sends API requests using relative `/api/mus/...` paths.

4\. The frontend Nginx server forwards those API requests to the `webgateway` service.

5\. The Web Gateway forwards the requests into InterSystems IRIS.

6\. The IRIS backend validates and resolves the requested operation.

7\. If an AI decision is required, IRIS calls the local LLM service.

8\. The backend returns an updated state snapshot to the frontend.

9\. The frontend refreshes the table, tournament, score, or action view.

This keeps the external browser-facing interface simple while preserving a clean internal service separation.

**### 3.3 Public access points**

The current deployment exposes these main entry points:

- `http://localhost:5173`: the React application served by Nginx.

- `http://localhost:8080`: direct HTTP access to the Web Gateway, useful for backend/API testing.

- `https://localhost:8443`: HTTPS access to the Web Gateway when needed.

- `http://localhost:8000`: local LLM server endpoint, mainly useful for diagnostics.

- IRIS management and superserver ports are also exposed for backend administration and development workflows.

For normal gameplay, users only need the frontend URL.

**### 3.4 Why the frontend is containerized**

The frontend is now part of the production-style Docker deployment. This has several advantages:

- The full application starts from a single Docker Compose stack.

- The frontend is served exactly as a production static application.

- There is no need to run a separate Vite development server.

- Browser API requests can use stable relative paths.

- The frontend can proxy backend calls through Docker networking.

- The deployment is easier to explain, reproduce, and test.

This also avoids differences between local development URLs and containerized backend URLs.

**### 3.5 Internal Docker networking**

Inside Docker Compose, services communicate using service names and internal container ports.

This distinction is important:

- Host ports are used by the developer’s machine or browser.

- Internal service names are used by containers talking to each other.

For example, the browser can reach the Web Gateway through `localhost:8080`, but the frontend container reaches the same service through the Docker service name `webgateway`.

The frontend proxy should therefore target the internal Web Gateway service, not the host-published port.

---

**## 4. How Mus is played

Mus is a traditional Spanish card game usually played by four players divided into two teams of two. Team members sit opposite each other.

In this project, the usual table structure is:

- Team A: players P1 and P3.
- Team B: players P2 and P4.

The game is played in hands. Each player receives four cards, and each hand moves through a sequence of decisions and betting phases.

### 4.1 Simplified hand flow

A hand starts with the deal. After receiving cards, players decide whether they want Mus. If everyone wants Mus, players discard and receive replacement cards. If any player cuts Mus, the hand continues to the betting phases.

The main betting and comparison phases are:

- **Grande**: compares the cards from highest to lowest.
- **Chica**: compares the cards from lowest to highest.
- **Pares**: compares pair structures when applicable.
- **Juego**: compares game totals when applicable.
- **Punto**: used when there is no Juego.

At the end of the hand, points are awarded and added to the team score.

### 4.2 Card equivalences used by the rules

The backend applies Mus equivalences consistently in all lances:

- Threes (`3`) count as kings.
- Twos (`2`) count as aces.
- For point values, king, queen, jack, and three count as 10.
- Ace and two count as 1.

For Grande and Chica, winner resolution is lexicographic. The highest or lowest relevant card is compared first, then the next one, and so on.

### 4.3 Pair and Juego ordering

Pares are resolved in the order:

1. Duples.
2. Medias.
3. Pareja.

Ties are resolved by comparing the relevant pair ranks.

Juego follows the Mus order:

`31 > 32 > 40 > 39 > 38 > 37 > 36 > 35 > 34 > 33`

When no player has Juego, the hand is played at Punto, where 30 is the best total below 31.

Exact winner resolution is intentionally separated from AI hand-strength scoring. Winner methods compare the hands directly; AI strength scores are only signals used for betting strategy.

### 4.4 Common player actions

The most visible actions in the application are:

- **Pasar**: pass without betting.
- **Envidar**: make or raise a bet.
- **Querer**: accept a pending bet.
- **No querer**: refuse a pending bet.
- **Ordago**: challenge for the whole game.

The frontend displays only the actions that make sense for the current state, but the backend still validates every action before applying it.

### 4.5 Winning the game

A game continues until one team reaches the target score. The common target used by the application is 40 points.

When a team reaches the target, the backend marks the game as finished, stores the winner, and the frontend shows the final result.

### 4.6 Mus in this project

The implementation keeps exact comparison rules in backend helper methods and keeps AI strength evaluation separate from winner accounting.

For Grande and Chica, the AI helper calculates a positional strength score from the four normalized cards. The score is used only to classify the hand for strategic purposes (`very weak`, `weak`, `neutral`, `strong`, `very strong`); it is not used to determine the winner of a lance.

Exact ties are resolved according to table order/mano by preserving the first equal hand encountered by the winner-selection logic.

## 5. Backend architecture**

**### 5.1 Interoperability production**

The backend uses an InterSystems interoperability production as its orchestration layer.

This production coordinates the main application components:

- A game coordinator for game-related operations.

- A tournament coordinator for tournament-related operations.

- A rule engine for validating and resolving game actions.

- Persistence operations for storing and loading state.

- AI and LLM clients for autonomous player decisions.

- Message classes that define request and response contracts.

This architecture keeps responsibilities separated and makes the backend easier to evolve.

**### 5.2 Game coordinator**

The game coordinator handles the lifecycle of games and hands.

It receives requests from the API layer and coordinates the required backend operations. For example, when a player performs an action, the coordinator loads the current state, asks the rule engine to validate and resolve the action, persists the result, and returns the updated game state.

The same flow applies whether the action comes from a human player or from an AI recommendation. This is important because it ensures that AI players cannot bypass the rules.

**### 5.3 Rule engine**

The rule engine contains the Mus-specific logic.

It determines which actions are legal, how pending bets should be handled, when the game moves from one phase to the next, how a hand is closed, and how points are awarded.

By keeping this logic in the backend, the frontend remains simpler and the application avoids duplicating rule decisions across different layers.

**### 5.4 Persistence operations**

Persistence operations store and retrieve game and tournament data.

Game persistence includes information such as players, teams, cards, current hand, current phase, turn player, actions, scores, status, and winner.

Tournament persistence includes information such as tournament name, format, target score, teams, rounds, tables, table winners, tournament status, and final winner.

The persisted backend state is treated as the source of truth.

**### 5.5 Tournament coordinator**

The tournament coordinator manages tournament flows.

It is responsible for creating tournaments, listing them, loading details, deleting or hiding old tournaments, starting tables, completing tables, simulating agent-only games, and generating AI-assisted team suggestions.

When a tournament table contains only agent players, the backend can simulate the match automatically and then advance the tournament bracket using the resulting winner.

**### 5.6 Message contracts**

The backend uses typed message classes to communicate between API handlers, business processes, and operations.

This message-based approach helps keep the system organized because each use case has an explicit request and response shape. It also makes it easier to trace flows through the interoperability production.

---

**## 6. AI Hub and LLM integration

### 6.1 Purpose of the LLM layer

The LLM layer makes the game more dynamic by allowing AI players to reason over the current table context.

For betting phases, the backend sends the current player, phase, cards, scoreboard, profile, pending bet information, and legal action context. For discards it sends the hand and discard-specific context.

The model does not calculate game rules itself. It relies on narrowly scoped evaluation tools for hand analysis and then makes the strategic choice in a separate tool-free session.

The LLM is also used for creative generation, such as suggesting tournament names, team names, and player names.

### 6.2 AI Hub role

InterSystems AI Hub provides the agent, session, provider, and ToolSet abstractions used by the project.

The application uses separate `%AI.Agent.Session` instances for evaluation and decision. The evaluation session is configured with `max_iterations=1` so the model can make exactly one tool call in that stage.

ToolSets are filtered so an evaluation agent sees only the intended tool. Betting evaluation exposes only `EvaluatePlayStrength`, while discard evaluation exposes only `EvaluateDiscardHandValue`.

The decision agent is created without `UseToolSet()`, so it has no tools available and cannot accidentally request another tool after receiving the evaluation result.

### 6.3 Local llama.cpp model

The Docker stack includes a local OpenAI-compatible llama.cpp server.

The project has been adapted to local models that support native tool calling. Native tool parsers can be sensitive when a model is asked to perform a tool call and then emit final structured JSON in the same tool-enabled conversation.

To avoid that failure mode, the project separates evaluation and decision into two sessions and uses a compact final transport format:

`FINAL|actionType=<action>|amount=<number>|strength=<value>|confidence=<number>`

For discard decisions, the same transport also carries the selected cards.

### 6.4 Tool argument normalization

Local models do not always serialize array arguments identically. A cards argument may arrive as a real JSON array or as text resembling a Python list, for example:

`['12C', '6B', '11O', '6C']`

`Mus.AI.Tools.HandStrengthTools` normalizes the argument before scoring. It accepts both real dynamic arrays and serialized list forms, cleans each individual card, validates that exactly four cards are present, and then calls `Mus.AI.Helpers.HandStrengthHelper`.

Diagnostic fields such as `normalizedCards` and `normalizedCardCount` are included in the tool result to make model/tool integration problems easier to trace.

### 6.5 Hand-strength evaluation

`EvaluatePlayStrength` delegates the actual score to `Mus.AI.Helpers.HandStrengthHelper`.

For Grande and Chica, the current helper uses a direct positional score based on the four Mus-normalized card ranks. The sorted card qualities are weighted 40%, 30%, 20%, and 10%.

This score is deliberately separate from exact winner comparison:

- `CompareGrande` and `CompareChica` determine who wins those lances.
- `ComparePares`, `CompareJuego`, and `ComparePunto` determine the winner of the remaining comparison lances.
- `ScoreGrande` and `ScoreChica` classify strategic hand strength for the AI.

This separation prevents a heuristic betting score from changing the actual Mus winner.

### 6.6 Two-stage gameplay decision flow

The current gameplay AI flow is:

1. Build a compact evaluation prompt.
2. Create an evaluation agent with the exact required ToolSet.
3. Run one tool call only.
4. Extract the tool result from the AI Hub session context.
5. Create a new decision agent without tools.
6. Pass the raw tool result plus scoreboard, profile, pending-bet context, and exact legal candidates.
7. Ask the model to copy exactly one `FINAL|...` line.
8. Parse the selected line.
9. Apply mechanical normalization where required by the rules.
10. Validate and apply the action through the normal backend flow.

This pattern keeps tool execution deterministic while leaving the final strategic selection to the LLM.

### 6.7 Exact candidate output

The decision prompt presents a small set of exact candidate lines rather than asking the model to freely generate JSON.

For betting, candidates are derived from the current hand-strength category, legal actions, pending-bet state, and legal bet amounts.

For discard decisions, candidates are generated from the cards that the discard evaluation marks as eligible, plus the legal option to cut Mus when appropriate.

The model chooses one candidate exactly. This substantially reduces malformed responses and truncation with smaller local models.

### 6.8 Creative generation

Tournament content generation remains a separate use case from gameplay.

The tournament coordinator asks the model for realistic Castilian-style tournament, team, and player names. Prompts are intentionally stricter than normal creative generation so names stay believable and avoid fantasy, gothic, or esoteric naming styles.

### 6.9 Local and cloud providers

The AI Hub abstraction keeps model access portable. The project can run with the local llama.cpp endpoint for a self-contained demo or be adapted to another OpenAI-compatible/cloud provider.

The main gameplay architecture does not depend on a specific provider: the evaluation/decision split, ToolSet filtering, compact transport format, and backend validation remain the same.

## 7. Frontend and backend interaction

### 7.1 State loading

The frontend loads game and tournament state from the backend API and renders the table or tournament view from that state.

The frontend can show or hide controls for usability, but it does not own the final rule decisions. The backend validates and resolves every state-changing request.

Game-table refreshes are event-driven around actions and phase transitions. The table component schedules a delayed refresh after mutations so the next authoritative backend snapshot is rendered.

### 7.2 Human actions

When the user clicks an action button, the frontend sends the selected action to the backend.

The backend checks whether the action is valid in the current state, applies the result if legal, persists the updated game state, and returns a refreshed view of the game.

This flow ensures that human actions and AI actions pass through the same backend rule system.

### 7.3 Agent actions

When an AI player must act, the frontend requests the corresponding agent decision, applies the selected action through the normal action endpoint, and refreshes the game state afterwards.

Agent responses are visual feedback only. The authoritative action history and pending bet remain in backend game state.

### 7.4 Pending-bet visibility

The table now renders the current pending bet independently of temporary player-action messages.

This avoids losing the rival team's bet visually when local action bubbles are cleared during state or phase changes. While a pending bet exists, the UI keeps showing the aggressor and the amount that is waiting for a response.

### 7.5 Hand-result presentation

Hand-result formatting distinguishes points awarded in paso from other result reasons.

A single phase point without an explicit result reason is displayed as `1 en paso` instead of the incomplete `1 de`.

### 7.6 Tournament team suggestions

The tournament setup flow can ask the backend to generate team suggestions.

The backend uses the LLM to create a tournament name, team names, and player names. It then normalizes the result before returning it to the frontend.

The current generation prompt favors realistic old Spanish first names and separate nicknames, avoiding fantasy-style or implausible names.

## 8. Operating the application**

**### 8.1 Starting the stack**

The application is started as a Docker Compose stack from the repository root.

When the stack is running, the React application is available at `http://localhost:5173`.

The backend and Web Gateway are also available for direct testing or administration, but normal users interact with the frontend URL.

**### 8.2 Changing backend code**

Backend code lives under the IRIS source tree. Changes to backend classes usually require rebuilding or reloading the IRIS container so the updated ObjectScript code is compiled and the production uses the latest version.

**### 8.3 Changing frontend code**

Frontend code lives under the frontend project directory. Because the frontend is now deployed as a Dockerized production build, changes to frontend source files, dependencies, or Nginx configuration require rebuilding the frontend container.

There is no need to run the frontend manually with a development server for the documented deployment path.

**### 8.4 Changing the local model**

The local model server expects a model file to be available in the configured models directory.

Changing the model usually involves placing the new model file in the models directory and updating the model server configuration accordingly.

If a cloud model is used instead, the local model service can be replaced or bypassed depending on the chosen AI Hub configuration.

---

**## 9. Deployment troubleshooting**

**### 9.1 Frontend does not load**

If the browser cannot load the frontend, the first thing to check is whether the `mus-frontend` container is running and whether its Nginx server started correctly.

Typical causes include an invalid Nginx configuration, a failed frontend build, or a port conflict on the host machine.

**### 9.2 Frontend loads but backend calls fail**

If the UI appears but API calls fail, the most likely issue is the frontend-to-Web-Gateway proxy path.

Inside Docker, the frontend container must reach the Web Gateway by its Docker service name, not by the host address. The host-published Web Gateway port is for the developer machine, not for container-to-container traffic.

**### 9.3 Backend is unreachable**

If backend requests fail directly through the Web Gateway, check that both the IRIS backend and Web Gateway services are running and that the Web Gateway configuration points to the correct IRIS service.

**### 9.4 LLM decisions fail

If AI players cannot make decisions, check whether the local model server is running and whether the configured model file is available.

If using GPU acceleration, also check that the host has the required NVIDIA runtime support.

For gameplay-agent failures, inspect the two stages separately:

- **Evaluation stage**: confirm that exactly one tool call was made and that the tool result contains `success=1`.
- **Decision stage**: confirm that the tool-free session returned one valid `FINAL|...` candidate.

For hand-strength problems, inspect `normalizedCards`, `normalizedCardCount`, `score`, and `strength` in the `EvaluatePlayStrength` result. If normalized cards are correct but the score is not, test `Mus.AI.Helpers.HandStrengthHelper` directly in IRIS.

A useful diagnostic is `DiagnosticQualityVector(cards, play)`, which exposes the normalized Mus ranks, order indexes, quality vector, helper version, and calculated positional score for Grande or Chica.

### 9.5 Frontend build fails

If the frontend container fails during build, the cause is usually a TypeScript error or a dependency mismatch.

Because the Docker build uses the project lockfile, frontend dependencies must remain synchronized. TypeScript errors should be fixed in the source before rebuilding the container.

## 10. Extending the project**

**### 10.1 Adding new LLM providers**

The AI integration layer can be extended to use different local or cloud models. AI Hub is especially useful here because it allows the project to work through a provider abstraction instead of hardwiring the game logic to a single model endpoint.

**### 10.2 Improving agent behavior**

Agent behavior can be improved by refining prompts, adding richer player profiles, providing more compact game context, tuning model parameters, and adding stronger fallback strategies for invalid or low-quality responses.

The backend should continue to validate every AI recommendation regardless of how strong the model becomes.

**### 10.3 Improving tournaments**

Tournament features can be extended with richer bracket views, more formats, better summaries, manual result overrides, simulation logs, and better archive or deletion handling.

**### 10.4 Improving the frontend experience**

The frontend can be improved with clearer table animations, better action explanations, enhanced score visualizations, tournament progress indicators, and richer feedback when AI players make decisions.

---

**## 11. Architectural principles

The current project follows these principles:

1. **Backend owns the rules**: legal actions, state transitions, winner resolution, and scoring are authoritative server-side.
2. **Frontend is a state-driven UI**: it displays backend state and sends user actions.
3. **Evaluation and strategy are separated**: gameplay agents first obtain one narrow tool result, then make the strategic decision in a new session without tools.
4. **One tool call per evaluation stage**: evaluation sessions use `max_iterations=1` and ToolSets filtered to the exact required tool.
5. **Exact winner logic is separate from AI strength scoring**: heuristic hand-strength scores never determine the winner of Grande, Chica, Pares, Juego, or Punto.
6. **LLM output uses a compact transport contract**: final gameplay choices are returned as exact `FINAL|...` candidate lines instead of free-form JSON.
7. **Backend mechanically validates AI output**: the selected action is parsed, normalized where the rules require it, and passed through the normal legal-action flow.
8. **Pending bets remain authoritative in backend state**: the frontend may show transient action messages, but the active bet comes from the current game state.
9. **Docker-first deployment**: the full application runs as a coordinated Docker Compose stack.
10. **Frontend is production-served**: the React app is built and served by Nginx, not manually started with a development server.
11. **AI provider flexibility**: AI Hub and OpenAI-compatible patterns make local and cloud models possible.
12. **Clear service boundaries**: frontend, gateway, backend, and model runtime each have a distinct role.
13. **Tournament and game flows share backend consistency**: tournaments reuse the same game and AI foundations.

## 12. Glossary**

- ****Mus****: traditional Spanish partnership card game.

- ****Lance****: one of the betting or comparison phases in a hand.

- ****Grande****: phase that compares high cards.

- ****Chica****: phase that compares low cards.

- ****Pares****: phase that compares pairs.

- ****Juego****: phase that compares hand totals when players have game.

- ****Punto****: fallback phase used when there is no Juego.

- ****Envidar****: place or raise a bet.

- ****Querer****: accept a pending bet.

- ****No querer****: refuse a pending bet.

- ****Ordago****: challenge for the whole game.

- ****Amarraco****: traditional scoring marker worth five stones or points.

- ****Piedra****: traditional scoring stone or point marker.

- ****AI Hub****: InterSystems abstraction layer for working with AI providers.

- ****LLM****: Large Language Model.

- ****OpenAI-compatible endpoint****: API style commonly used by chat-completion model servers.

- ****Web Gateway****: InterSystems component that exposes IRIS web applications and APIs over HTTP.

---