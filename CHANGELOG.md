# Changelog

Todas as mudanças relevantes do app Lumink ficam registradas aqui.
As novidades para quem usa o app aparecem também dentro dele, em
**Lumink → Novidades do Lumink…** (`Sources/Lumink/Models/ReleaseNotes.swift`).
O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e
o projeto usa [versionamento semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

## [1.1.0] - 2026-11-08

### Adicionado

- Envio pelo app oficial **Send to Kindle** da Amazon, ligado por padrão: o
  Lumink abre o EPUB no app e o login fica com a Amazon, sem senha no Lumink.
  Os Ajustes mostram se o app está instalado e onde baixar.
- Liga/desliga separado para o app e para o e-mail (SMTP). Com os dois
  ligados, o app tem prioridade e o e-mail entra quando o app não está instalado.
- **Interface em inglês.** O app segue o idioma do macOS: português para quem
  usa o sistema em português, inglês para os outros idiomas. Dá para escolher
  só para o Lumink em Ajustes do Sistema → Geral → Idioma e Região →
  Aplicativos.
- **Idioma do livro.** O app detecta o idioma pelo texto do PDF (ou pelo texto
  do OCR, nos escaneados) e grava no EPUB. O Kindle usa esse idioma para o
  dicionário, a hifenização e a leitura em voz alta. Na revisão de título e
  autor, um menu *Idioma* permite trocar.
- O idioma escolhido também vai para a frente da lista do OCR, que dá
  prioridade a ele.
- `--language` no `--process`, para testar o idioma escolhido pela linha de
  comando.

### Alterado

- A aba de Ajustes "Kindle e e-mail" virou "Envio". Os campos de SMTP só
  aparecem com o e-mail ligado, e servidor e porta ficam em linhas separadas.
- Quem já tinha um remetente configurado continua com o e-mail ligado.
- Os detalhes de cada livro na fila mostram o idioma detectado (ex.:
  "PDF com texto · 220 páginas · inglês").
- A prévia do `--snapshot` usa os textos do pipeline e sai no idioma do app.

### Corrigido

- Todo EPUB saía marcado como português (`--language pt` fixo no Calibre e
  `dc:language` fixo no Modo imagem), mesmo com o livro em inglês.

## [1.0.0] - 2026-11-08

Primeira versão. App nativo para macOS 14+ (Swift + SwiftUI) que recebe um
livro em PDF, converte para EPUB, comprime e envia para o Kindle.

### Destaques

- **De PDF a Kindle numa etapa só**: você arrasta o PDF e o app analisa, faz o
  OCR se precisar, converte, comprime e envia.
- **Funciona com PDFs escaneados**: o OCR reconhece português e inglês, e o
  EPUB tem texto que se ajusta à tela, não uma foto por página.
- **Modo imagem para HQ e mangá**: gera um EPUB3 de layout fixo, com uma
  imagem por página. Liga sozinho quando o PDF quase não tem texto.
- **Cabe no limite do e-mail**: comprime as imagens em até três níveis e avisa
  quando o livro ainda passa do limite.

### Entrada e fila

- Recebe PDFs arrastados para a janela ou para o ícone do Dock, por
  *Abrir com* no Finder, ou pelo botão **Escolher PDF…** (⌘O).
- Fila serial: processa vários arquivos, um de cada vez, mostrando a etapa e o
  progresso de cada um.
- Revisão opcional de título e autor (lidos do PDF) antes de processar, com os
  botões **Processar** e **Processar todos**.
- Modo imagem configurável por item ou como padrão.
- Opção **Só gerar**, que salva o EPUB em `~/Documents/Lumink/` sem enviar.
- Janela **Novidades do Lumink** (menu *Lumink → Novidades do Lumink…*), que
  abre sozinha na primeira execução de cada versão.

### Análise e OCR

- Detecta o tipo do PDF (texto, escaneado ou misto) amostrando até 30 páginas
  com o PDFKit.
- OCR com `ocrmypdf --skip-text` (idiomas configuráveis, padrão `por+eng`). Se
  ele não estiver instalado ou falhar, usa o Vision da Apple.
- `TextLayerPDFBuilder`: como o Calibre ignora texto invisível, o app monta um
  PDF intermediário em que o texto do OCR fica visível, para o reflow
  funcionar.

### Conversão

- Calibre `ebook-convert` com o motor `calibre` e saída EPUB 3 no perfil
  `kindle_pw3`. Remove cabeçalhos, rodapés e números de página soltos, e usa
  heurísticas para juntar linhas e desfazer hifenização.
- O progresso da conversão aparece em tempo real.

### Compressão

- Três níveis: Alta (1600 px, JPEG 85%), Média (1600 px, 75%) e Máxima
  (1200 px, 55%).
- Processa as imagens em paralelo com o ImageIO. PNGs opacos viram JPEG, e as
  referências no HTML, CSS e OPF são atualizadas. Uma imagem só é trocada se a
  nova versão for menor.
- Se o EPUB passar do limite, o app tenta o nível seguinte. Se ainda passar,
  salva o arquivo e não envia.

### Envio

- Envio por SMTP usando o `curl` que já vem no macOS, sem dependências novas:
  SMTPS na porta 465, STARTTLS obrigatório nas outras.
- Mensagem MIME montada pelo próprio app, com acentos no assunto e no nome do
  anexo codificados (RFC 2047 e 2231).
- A senha fica só no Keychain e chega ao `curl` pelo stdin. Não aparece no
  `ps` nem é gravada em disco.
- Limite automático de ~18 MB de anexo no Gmail (o Gmail recusa mensagens
  acima de 25 MB).
- Botão **Enviar e-mail de teste**, que manda uma mensagem sem anexo para o
  próprio remetente.
- Mensagens de erro em português para as falhas mais comuns: login recusado,
  servidor não encontrado, TLS, tempo esgotado e mensagem grande demais.

### Ferramentas e depuração

- Aviso no topo da janela quando falta o Calibre ou o ocrmypdf, com as
  instruções de instalação.
- Logs via `os.Logger` (subsistema `local.lumink`).
- Modos de linha de comando: `--process`, `--compress`, `--keychain-test`,
  `--snapshot` e `--snapshot-notes`.
- `build-app.sh`: compila com `swiftc`, escolhe sozinho um SDK compatível e
  assina o app ad-hoc.
- Ícone do app: uma chama sobre um traço de tinta, em fundo azul-tinta. Gerado
  por `Scripts/make-icon.swift`, que também cria o favicon do site.
- Script para gerar PDFs de teste (texto, escaneado e misto).
- Site de apresentação (Next.js, export estático) em `site/`.

### Limitações conhecidas

- O Modo imagem não tem leitura da direita para a esquerda (mangá japonês).
- Em PDFs mistos, figuras dentro de páginas escaneadas não vão para o EPUB.
- O OCR do Vision é bem mais lento que o do ocrmypdf.
- O envio exige configurar o SMTP e uma senha de app.

[Não lançado]: https://github.com/indiorlei/lumink-app/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/indiorlei/lumink-app/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/indiorlei/lumink-app/releases/tag/v1.0.0
