# The Legend of Zelda: The Minish Cap — PortMaster (Trimui Smart Pro + KNULLI)

PortMaster packaging of [Project Picori](https://github.com/999sian/tmc) (*The Legend of Zelda: The Minish Cap* native PC port), tailored and tested for the **Trimui Smart Pro** running **KNULLI OS** (Allwinner A133P / aarch64 / 1280×720).

[English](#english) | [Português](#português)

---

<a name="english"></a>
## 🇬🇧 English

### 💡 What is this project? (Explained Simply)
Normally, retro handheld consoles run Game Boy Advance games using an **emulator** (software that simulates the entire original GBA hardware).

This project is an **adaptation for handheld consoles of the native PC port** ([Project Picori](https://github.com/999sian/tmc)):
* **Native Execution**: The original game code was decompiled and rebuilt to run **directly on the Trimui Smart Pro's ARM processor**, exactly like a native PC game, without needing any emulator.
* **Why is that cool?**: It runs as a standalone app via **PortMaster**, allowing custom 4× integer scaling (960×640) for crisp, sharp visuals on the 720p screen without blurry bilinear stretching.
* **Why do I still need a ROM?**: To respect Nintendo's intellectual property, this repository contains **only the open-source game engine**. No game graphics, music, or text are distributed here. When you provide your own GBA ROM once, the engine extracts the assets locally on your console and boots straight into the adventure!

> [!WARNING]
> **Early Build / Performance Notice:** This is an initial port release based directly on the native PC port (*Project Picori*). Because this early iteration relies on a CPU software rasterizer running on handheld ARM hardware via an SDL3 compatibility shim, you may encounter performance bottlenecks, occasional frame drops, and audio stuttering in demanding scenes. Future performance improvements and optimizations are still being explored.

### 🎮 How to Run

#### 1. Requirements
* A **Trimui Smart Pro** running **KNULLI** (or compatible `aarch64` handheld running PortMaster).
* A legally acquired Game Boy Advance ROM of *The Legend of Zelda: The Minish Cap*:
  * `baserom.gba` (USA version — recommended)
  * `baserom_eu.gba` (European version)
  * `baserom_jp.gba` (Japanese version)
  * *Note: No copyrighted ROM files or Nintendo game assets are included in this repository.*

#### 2. Installation
1. **Download the Port**: Grab the latest `picori.zip` from the [Releases](../../releases) tab (or build it yourself using `./build.sh 2.0.0`).
2. **Extract to Ports directory**:
   * On KNULLI: extract the contents of `picori.zip` into `/userdata/roms/ports/`.
   * You should have:
     * `/userdata/roms/ports/Legend of Zelda - The Minish Cap.sh`
     * `/userdata/roms/ports/picori/` (containing `tmc_pc.aarch64`, `libs.aarch64/`, etc.)
3. **Add your GBA ROM**:
   * Copy your ROM file to `/userdata/roms/ports/picori/baserom.gba`.
4. **Update Gamelist & Play**:
   * On your device, press **Start** in EmulationStation → **Game Settings** → **Update Gamelists**.
   * Launch **The Legend of Zelda: The Minish Cap** from the **Ports** collection.
   * On the first boot, the engine will automatically extract the sound and graphic assets from your ROM (takes ~5–10 seconds) and launch directly into the game.

#### 🕹️ Controls (Trimui Smart Pro)
Configured via `gptokeyb2`:
* **D-Pad / Left Analog Stick**: Movement
* **A Button**: Interact / Roll / Confirm
* **B Button**: Sword / Cancel
* **X / Y Buttons**: Assigned items
* **L1 / R1**: Shield / Items
* **Start**: Pause / Status Menu
* **Select**: Inventory / Map
* **Select + Start**: Exit Game

> [!IMPORTANT]
> **Renderer Warning:** Keep the in-game `render_backend` set to **`software`** (default). Do **NOT** switch to GPU rasterizer on handheld devices, as OpenGL desktop shaders are not supported via the SDL3-on-SDL2 shim and will prevent the game from starting.

---

<a name="português"></a>
## 🇧🇷 Português

### 💡 O que é este projeto? (Explicado de forma simples)
Normalmente, consoles portáteis como o Trimui Smart Pro rodam jogos de Game Boy Advance através de um **emulador** (um programa que imita o videogame antigo rodando por cima do sistema).

Este projeto é uma **adaptação para consoles portáteis a partir do port nativo de PC** ([Project Picori](https://github.com/999sian/tmc)):
* **Sem emulador**: O código-fonte original de *The Legend of Zelda: The Minish Cap* foi reconstruído por engenharia reversa (descompilação) e recompilado para rodar **diretamente no processador do Trimui Smart Pro**, como se fosse um jogo de PC feito nativamente para ele.
* **Qual a vantagem?**: Ele roda como um jogo próprio via **PortMaster**, aproveitando a tela de 1280×720 com resolução pixel-perfect (escala 4× de 960×640), deixando a imagem super nítida e sem o borrão de estiramento dos emuladores.
* **Por que ainda preciso da ROM?**: Por respeito aos direitos autorais da Nintendo, este projeto disponibiliza **apenas o motor do jogo (código)**. Nenhuma imagem, música ou texto protegido está incluso. Ao colocar sua própria ROM do jogo uma única vez, o motor extrai os arquivos necessários diretamente no aparelho e inicia a aventura!

> [!WARNING]
> **Versão Inicial / Aviso de Desempenho:** Esta é uma versão inicial adaptada diretamente do port nativo de PC (*Project Picori*). Por ser uma versão preliminar rodando através de rasterizador por software na CPU do console portátil (Allwinner A133P) e via shim de compatibilidade SDL3, o jogo apresenta problemas e oscilações de desempenho (quedas de FPS e eventuais engasgos no áudio em cenas mais pesadas). Melhorias e otimizações de performance continuam em andamento.

### 🎮 Como Jogar / Instalar

#### 1. Requisitos
* Um **Trimui Smart Pro** rodando o sistema **KNULLI** (ou console portátil `aarch64` compatível com PortMaster).
* Uma cópia da ROM de Game Boy Advance do *The Legend of Zelda: The Minish Cap*:
  * `baserom.gba` (Versão Americana — recomendada)
  * `baserom_eu.gba` (Versão Europeia)
  * `baserom_jp.gba` (Versão Japonesa)
  * *Aviso: Nenhum arquivo de ROM ou asset proprietário da Nintendo está incluso neste repositório.*

#### 2. Passo a Passo de Instalação
1. **Baixar o Port**: Baixe o `picori.zip` mais recente na aba de [Releases](../../releases) (ou gere pelo script `./build.sh 2.0.0`).
2. **Copiar para a pasta de Ports**:
   * No KNULLI: extraia o conteúdo do `picori.zip` direto em `/userdata/roms/ports/`.
   * A estrutura de pastas deve ficar assim:
     * `/userdata/roms/ports/Legend of Zelda - The Minish Cap.sh`
     * `/userdata/roms/ports/picori/` (com `tmc_pc.aarch64`, `libs.aarch64/`, etc.)
3. **Colocar a ROM do GBA**:
   * Coloque a sua ROM dentro da pasta `/userdata/roms/ports/picori/` renomeada para `baserom.gba`.
4. **Atualizar a lista de jogos e Jogar**:
   * No Trimui, aperte **Start** no menu principal → **Game Settings** → **Update Gamelists**.
   * Abra **The Legend of Zelda: The Minish Cap** na aba de **Ports**.
   * No primeiro carregamento, o port extrairá automaticamente as músicas e gráficos da ROM (leva apenas ~5 a 10 segundos) e abrirá o jogo diretamente em tela cheia!

#### 🕹️ Mapeamento de Controles (Trimui Smart Pro)
Mapeados através do `gptokeyb2`:
* **D-Pad / Analógico Esquerdo**: Movimentação
* **Botão A**: Interagir / Rolar / Confirmar
* **Botão B**: Espada / Cancelar
* **Botões X / Y**: Itens equipados
* **L1 / R1**: Escudo / Itens secundários
* **Start**: Pausar / Menu de Status
* **Select**: Inventário / Mapa
* **Select + Start**: Sair do jogo

> [!IMPORTANT]
> **Aviso sobre o Renderizador:** Mantenha a opção de renderizador em **`software`** (padrão). **NÃO** mude para GPU nas opções dentro do jogo; no Trimui Smart Pro o renderizador por software roda a 60 FPS cravados e a GPU trava pelo shim SDL3-sobre-SDL2.

---

## 🛠️ Project Structure / Estrutura do Projeto

```text
port/                                   The PortMaster package / O pacote PortMaster
  Legend of Zelda - The Minish Cap.sh   Launcher script with 720p 4x integer scaling
  port.json  gameinfo.xml  README.md  screenshot.png  cover.png
  picori/
    config.json                         Preconfigured settings (software renderer, 60fps)
    picori.ini                          gptokeyb2 controller mapping
    licenses/                           Open source licenses
    tmc_pc.aarch64                      Native engine (added by build.sh)
    libs.aarch64/libSDL3.so.0           SDL3-on-SDL2 shim
build.sh                                Assembles dist/<version>/picori.zip
Dockerfile.arm64-bullseye               Debian bullseye builder container (glibc 2.31)
```

## ⚙️ How it runs / Como Funciona

* **Engine**: `tmc_pc` é um executável SDL3 nativo compilado para `linux-arm64` a partir da branch `rg35xx-sp-audio-ui` do [lorencouse/tmc](https://github.com/lorencouse/tmc).
* **Compatibilidade**: Os portáteis usam SDL2 nativo. O pacote inclui o shim `libSDL3.so.0` para traduzir as chamadas da SDL3 diretamente para a SDL2 do Knulli em tempo de execução.
* **Resolução**: Em telas 1280×720 (Trimui Smart Pro), o launcher ativa automaticamente o **integer scaling 4×** (960×640) com pixels perfeitos e sem borrão bilinear.

## 👥 Credits & Acknowledgements / Créditos e Agradecimentos

This project is an adaptation of the incredible work done by the open-source decompilation and reverse-engineering community. All credit goes to the original authors:

* **[zeldaret/tmc](https://github.com/zeldaret/tmc)**: The decompilation team who painstakingly reverse-engineered *The Legend of Zelda: The Minish Cap* into clean, matching C code.
* **[999sian](https://github.com/999sian) & Contributors ([Project Picori](https://github.com/999sian/tmc))**: Creators of the original native PC port, developing the software PPU rasterizer, SDL3 integration, audio engine, and PC features.
* **[lorencouse](https://github.com/lorencouse) ([lorencouse/tmc](https://github.com/lorencouse/tmc) & [muos-rg35xx-sp-picori](https://github.com/lorencouse/muos-rg35xx-sp-picori))**: Created the handheld fork with linear audio resampling (44.1 kHz), screen UI scaling, SDL3-on-SDL2 runtime shim, and reference PortMaster packaging.
* **[PortMaster Community](https://portmaster.games/)**: The framework, scripts, and runtime utilities (`gptokeyb2`, `libinterpose`) that make native ports possible on retro handhelds.
* **KNULLI OS & Trimui Smart Pro Community**: Testing, packaging, and verifying native compatibility for the Trimui Smart Pro (Allwinner A133P / 1280×720).

---

## 📜 License / Licença

GPL-3.0-or-later, mesma licença do Project Picori. Nenhum dado proprietário do jogo está incluído.
