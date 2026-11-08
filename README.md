# Lumink

**Converta, comprima e envie seus PDFs para o leitor digital em um só gesto.**

App nativo para macOS (Swift + SwiftUI) que recebe livros em PDF, converte para
EPUB, comprime e envia para o seu Kindle por e-mail (Send to Kindle).
Uso pessoal, fora da App Store, sem App Sandbox.

## Por que Lumink?

Lumink junta duas palavras: *lume*, do português, e *ink*, do inglês.

**Lume** é uma palavra antiga e poética da nossa língua. Significa fogo, chama,
luz, e vem do latim *lumen*, de onde também vêm "luminoso" e "iluminar". Está na
expressão "vir a lume", que quer dizer ser publicado, ser trazido à luz ("o
romance veio a lume em 1899"). É o que o app faz: pega um livro preso num PDF
pesado e o traz a lume, pronto para ser lido.

**Ink** é tinta. A palavra lembra a tela de tinta eletrônica dos leitores
digitais, que imita o papel e deixa a leitura confortável por horas. É o
destino de cada livro que passa pelo app.

Juntas, as duas palavras guardam uma referência discreta: em inglês, *kindle*
significa acender. O lume é essa chama, e a tinta é onde ela acende.

*Lumink: a luz que leva o seu livro até a tinta.*

```
PDF ─▶ Analisando ─▶ OCR (se escaneado/misto) ─▶ Convertendo ─▶ Comprimindo ─▶ Enviando
        PDFKit        ocrmypdf ou Vision          Calibre ou     ImageIO        curl (SMTP)
                                                  Modo imagem
```

## 1. Instalar as dependências

| O quê | Para quê | Como |
|---|---|---|
| Xcode **ou** Command Line Tools | compilar | `xcode-select --install` |
| Calibre | converter PDF → EPUB (obrigatório, exceto no Modo imagem) | `brew install --cask calibre` ou [calibre-ebook.com](https://calibre-ebook.com/download_osx) |
| ocrmypdf + idiomas | OCR de PDFs escaneados (opcional; sem ele o app usa o Vision da Apple) | `brew install ocrmypdf tesseract-lang` |

`tesseract-lang` traz o idioma `por`. Sem ele, o ocrmypdf só reconhece inglês.

Se faltar algo, o app mostra um aviso no topo da janela com as instruções, e
continua funcionando no que for possível.

## 2. Compilar e abrir

```bash
cd app
./build-app.sh            # release → build/Lumink.app
open build/Lumink.app
cp -R build/Lumink.app /Applications/   # opcional
```

O script chama o `swiftc` diretamente e assina o app ad-hoc (`codesign -s -`).
Como o app é compilado na sua máquina, o Gatekeeper não bloqueia a abertura.

**Sobre o SwiftPM/Xcode:** o `Package.swift` abre no Xcode (File → Open) se você
preferir. Nesta máquina o `swift build` falha por causa de uma instalação
inconsistente das Command Line Tools: o `libPackageDescription` não bate com o
compilador, e o SDK 27.2 pede os plugins de macro do SwiftUI, que só vêm com o
Xcode. O `build-app.sh` contorna os dois problemas e escolhe automaticamente um
SDK compatível. Para consertar as CLT:
`sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.

## 3. Configurar o envio (⌘, → "Envio")

São duas opções, cada uma com seu liga/desliga. Com as duas ligadas, o Lumink
usa o app quando ele está instalado e o e-mail nos outros casos.

### App Send to Kindle (recomendado, padrão)

Instale o app oficial da Amazon para Mac em <https://www.amazon.com/sendtokindle>
e entre com a sua conta Amazon nele. No fim do processamento, o Lumink abre o
EPUB no Send to Kindle, e você escolhe o dispositivo e confirma o envio lá. Não
precisa de senha, servidor nem lista de remetentes aprovados, e o limite é de
200 MB.

### E-mail (Gmail ou outro SMTP)

Envia sozinho, sem abrir outro app. Ligue *E-mail* e preencha:

1. **E-mail do Kindle**: em amazon.com.br → *Gerenciar conteúdo e dispositivos* →
   *Preferências* → *Configurações de documentos pessoais*. Termina em `@kindle.com`.
2. **Autorizar o remetente**: na mesma página, em *Lista de e-mails aprovados
   para documentos pessoais*, adicione o seu e-mail remetente. Sem isso, a
   Amazon descarta os envios em silêncio.
3. **Senha de app do Gmail**: ative a verificação em duas etapas e crie uma em
   <https://myaccount.google.com/apppasswords>. Cole no campo *Senha de app* e
   clique em *Salvar no Keychain*. Os espaços são removidos automaticamente.
4. Servidor `smtp.gmail.com`, porta `465` (o padrão).
5. Clique em **Enviar e-mail de teste**. O teste vai para o próprio remetente,
   sem anexo: valida servidor, porta e senha sem gastar um documento no Kindle.

A senha fica **só no Keychain** (serviço `local.lumink.smtp`), nunca em
UserDefaults ou em arquivo. Como cada build tem uma assinatura ad-hoc nova, o
macOS pode perguntar uma vez se o Lumink pode acessar a senha. Clique em
*Permitir sempre*.

**Limite de tamanho (e-mail):** o Send to Kindle por e-mail aceita até 50 MB, mas o **Gmail recusa
mensagens acima de 25 MB**. Com a codificação base64 (+33%), sobram ~18 MB de
anexo. Quando o servidor é o Gmail, o app usa 18 MB como limite automaticamente.

## 4. Usar

- Arraste PDFs para a janela, para o ícone do Dock, ou use **Escolher PDF…** (⌘O).
  Vários arquivos são processados em fila, um por vez.
- Com *Revisar título e autor antes de processar* ligado (padrão), cada PDF
  espera você conferir os metadados (lidos do PDF) e clicar em **Processar**
  (ou **Processar todos**).
- **Modo imagem (HQ/mangá)**: por item ou como padrão na barra de ferramentas.
  Pula o OCR e gera um EPUB3 de layout fixo, com uma imagem por página.
- **Só gerar**: salva o EPUB sem enviar.
- **Qualidade**: Alta (1600 px, JPEG 85%), Média (1600 px, 75%) ou Máxima
  compressão (1200 px, 55%).

Os EPUBs ficam em `~/Documents/Lumink/`. Os arquivos temporários ficam em
`$TMPDIR/Lumink/<uuid>`, uma pasta por item, apagada no fim (e também na
abertura do app, se sobrar algo de uma execução interrompida).

## Como funciona

**Detecção do tipo.** O PDFKit extrai o texto de até 30 páginas espalhadas pelo
livro. Uma página "tem texto" com 40 ou mais caracteres. Se ≥ 90% das páginas
têm texto, o PDF é de texto; se < 50%, é escaneado; senão, é misto.

**OCR.** Usa o `ocrmypdf --skip-text -l por+eng` (os idiomas são configuráveis).
Se ele não estiver instalado ou falhar, usa o Vision (`VNRecognizeTextRequest`,
modo *accurate*, pt-BR + en-US). Se um PDF escaneado render quase nenhum texto
(HQ, fotos), o app muda sozinho para o Modo imagem.

> **Descoberta importante:** o Calibre (os dois motores, `calibre` e
> `pdftohtml`) **ignora texto invisível**, que é como o OCR grava a camada de
> texto. Por isso o app não entrega ao Calibre o PDF do ocrmypdf direto: ele
> monta um PDF intermediário (`TextLayerPDFBuilder`) em que as páginas
> escaneadas viram texto *visível* nas mesmas posições, sem a imagem do scan.
> Assim o reflow funciona e o EPUB não carrega uma foto por página.
> Consequência: figuras dentro de páginas *escaneadas* não vão para o EPUB.
> Para livros muito ilustrados, use o Modo imagem.

**Conversão.** `ebook-convert` com o motor `calibre`, remoção automática de
cabeçalhos e rodapés repetidos (`--pdf-header-skip -1 --pdf-footer-skip -1`),
uma regex para números de página soltos, `--enable-heuristics` (junta linhas,
remove hifenização), perfil `kindle_pw3`, EPUB 3, título, autor e idioma. O
progresso vem das linhas `NN%` do stdout.

**Compressão.** O app descompacta o EPUB e processa as imagens em paralelo
(ImageIO). Elas são redimensionadas para no máximo N px de altura; os JPEGs são
reencodados; PNGs opacos de 40 KB ou mais viram JPEG (a transparência é
verificada pixel a pixel). Uma imagem só é substituída se ficar menor. Quando um
PNG vira JPEG, as referências no HTML, CSS e OPF e o `media-type` são
atualizados. Por fim o app recompacta com `mimetype` como primeira entrada, sem
compressão (`zip -X -0`). Se o EPUB passar do limite, tenta o nível seguinte;
se ainda passar, salva, marca ❌ e não envia.

**Envio: por que `curl`.** O `curl` já vem no macOS, tem SMTPS/STARTTLS e TLS
bem testados, e não adiciona nenhuma dependência. Os pacotes Swift de SMTP
estão pouco mantidos e trariam TLS e autenticação próprios para auditar. O app
monta a mensagem MIME (multipart, base64, nome do anexo e assunto com acentos
codificados pelas RFCs 2231 e 2047). **A senha vai para o curl pelo stdin**
(`--config -`), então não aparece no `ps` nem em arquivo no disco. A porta 465
usa `smtps://`; as outras usam `smtp://` com `--ssl-reqd` (STARTTLS obrigatório).

## Depuração

Logs (`os.Logger`, subsistema `local.lumink`, categorias `queue`, `analyze`,
`ocr`, `convert`, `compress`, `mail`, `process`):

```bash
log stream --predicate 'subsystem == "local.lumink"' --level debug
```

O binário também tem modos de linha de comando, úteis para testar sem a interface:

```bash
KP=build/Lumink.app/Contents/MacOS/Lumink
$KP --process livro.pdf                 # pipeline completo, só gera o EPUB
$KP --process hq.pdf --image-mode --level maximum
$KP --process livro.pdf --vision        # força o OCR do Vision
$KP --process livro.pdf --send          # envia com as configurações do app
$KP --compress in.epub out.epub medium  # só a compressão
$KP --keychain-test                     # grava/lê/apaga uma senha de teste
$KP --snapshot janela.png               # renderiza a janela com itens de exemplo
$KP --snapshot-notes novidades.png      # renderiza a janela de novidades
```

PDFs de teste (texto, escaneado e misto): `swift Scripts/make-test-pdfs.swift` → `TestData/`.

Ícone (uma chama, o lume, sobre um traço de tinta): `swift Scripts/make-icon.swift`.
Gera `Resources/AppIcon.icns` e os ícones do site (`favicon.ico`, `icon.png`,
`apple-icon.png`). Depois rode o `./build-app.sh`.

## Estrutura

```
Sources/Lumink/
  App/         LuminkApp, AppDelegate (Dock/Abrir com), Log, TempWorkspace, DebugCommands
  Models/      BookJob (+JobReporter), PipelineStage, CompressionLevel, AppSettings
  ViewModels/  QueueViewModel (fila serial), SettingsViewModel
  Views/       MainView, DropZoneView, JobRowView, MetadataEditor, DependencyBanner, SettingsView
  Services/    ProcessRunner, DependencyChecker, PDFAnalyzer, PDFPageRenderer,
               OCRService, OCRmyPDFEngine, VisionOCREngine, TextLayerPDFBuilder,
               CalibreConverter, ImageModeConverter, EPUBArchive, EPUBCompressor,
               ImageRecompressor, ImageEncoder, MailComposer, MailSender, KeychainStore
  Pipeline/    BookPipeline (orquestra as etapas)
```

## Limitações conhecidas

- Modo imagem: não há leitura da direita para a esquerda (mangá japonês). O
  Kindle mostra na ordem do PDF.
- PDFs mistos: figuras dentro de páginas escaneadas são descartadas (veja acima).
- O OCR do Vision é bem mais lento que o ocrmypdf, e mais ainda na primeira
  execução, quando carrega os modelos.
