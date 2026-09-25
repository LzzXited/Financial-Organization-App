# Minhas Finanças: como gerar o APK

1. Crie uma conta grátis em https://github.com (se ainda não tiver).
2. Clique em **New repository**, dê o nome `minhas-financas`, marque **Private** e clique em **Create repository**.
3. Na página do repositório, clique em **uploading an existing file**.
4. Descompacte o zip no computador e arraste **tudo o que está dentro da pasta `financas`** para a página
   (inclusive a pasta `.github`). Clique em **Commit changes**.
5. Abra a aba **Actions**. O "Gerar APK" começa sozinho e leva uns 8 a 12 minutos.
6. Quando ficar verde, abra a aba **Releases** (lado direito da página inicial do repositório) e baixe
   `MinhasFinancas-vX.apk`. Dá para abrir essa página direto no celular e instalar.

**Se a aba Actions estiver vazia:** clique em Actions → "set up a workflow yourself" e cole o conteúdo do
arquivo `.github/workflows/build-apk.yml`. Depois clique em Commit.

**Importante:** não apague `android/app/financas.jks` nem `android/key.properties`. Eles são a "chave" do app.
Com eles, as próximas versões instalam por cima sem perder os seus dados.
Deixe o repositório como **Private**.
