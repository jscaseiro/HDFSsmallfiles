# Contexto dos arquivos pequenos no HDFS
## Funcionamento do HDFS NameNode

O HDFS foi desenvolvido para tratar eficientemente arquivos grandes, baseado no tamanho do bloco. A plataforma da Cloudera utiliza como padrão o tamanho do bloco com 128MB. Ou seja, é recomendável que os dados ingeridos no cluster sejam tratados e somente ser armazenados com o tamanho igual ou maior do que o tamanho do bloco. No caso de grandes volumes, avaliar também os tamanhos quando utilizar algoritmos de compactação. 

Avaliando o NameNode, serviço de categoria Master, no quesito de uso de memória: todo arquivo, diretório e bloco representam um objeto na memória com a ocupação de 150 bytes, como regra geral. Com base nessa informação, é possível dimensionar quanto deverá ser utilizado de memória na escolha do Hardware.

**Exemplo:** Para 10 milhões de arquivos, utilizando um bloco cada, necessitaríamos em média de 3Gb de memória para o processo do Namenode.

Uma informação importante é que o limite total de arquivos conhecidos para o HDFS, para garantir alto desempenho é de 300 milhões de arquivos.

## Impactos no HDFS NameNode (NN)

Avaliando as funções do serviço, quando temos uma grande quantidade de arquivos pequenos no HDFS, é gerado um alto consumo de buscas de localicação dos blocos onde se encontram os dados pequisado e perda de tempo nessa consulta, pela alta distribuição da infromação, além da solicitação dos arquivos, quando menores do que deveria, aumentando na quantidade de requisições entre os DataNodes. 
Ilustrando o cenário dos problemas de arquivos pequenos:

**Cenário de um arquivo grande de 192MiB**
- 1 arquivo = 1 bloco de 128MB + um bloco de 64MB, depois da replicação teríamos: 3 blocos de 128MB e 3 blocos de 64MB, fazendo a conta de utilização de memória:
  - 150 bytes * (1 arquivo inode + (Nro. de blocos * fator de replicação)) = 150 * (1 + (2 * 3)) = 1050 Bytes \\approx 1KB

**Cenário com 192 arquivos pequenos de 1MiB cada**
- 192 arquivos = 192 blocos de 128MB , depois da replicação teríamos: 576 blocos de 128MB, fazendo a conta de utilização de memória:
  - 150 bytes * (1 arquivo inode + (Nro. de blocos * fator de replicação)) = 150 * (192 + (192 * 3)) = 115200 Bytes \\approx 112KB

**Conclusão:** Com o uso de arquivos pequenos seria necessário mais de 100 vezes o uso de memória para tratar o mesmo volume.

## Apresentando os problemas com mais detalhes
- O NN mantém os registros de alteração de localização dos blocos no cluster, com muitos arquivos pequenos, o NN pode apresentar erro de falta de memória antes da falta de espaço em disco dos DataNodes (DN);
- Os DNs fazem o relatório de alteração de blocos para o NN através da rede, quanto mais blocos, mais alterações para ser reportados através da rede, com isso aumentando o fluxo e utilização de banda na comunicação;
- Quanto mais arquivos, mais solicitações de leitura precisam ser respondidas pelo NN, com isso aumentando a fila de RPC e a latência do processamento, degradando o desempenho e tempo de resposta. Uma demanda de RPC aceitável seria perto de 40K~50K RPCs/s;
- Pensando na manutenção do serviço, quando o NN reinicia, todos os metadados são carregados do disco para a memória, com arquivos pequenos, o tamanho dos metadados aumenta e torna o reinício lento.

Em face aos possíveis impactos, principalmente de lentidão do cluster, faz-se necessário o uso de ferramentas para identificação dos ofensores e visualização dos objetos que estão gerando os problemas, para facilitar a criação de um plano de ação.

# Passo a passo para coleta das informações do HDFS FSCK e criação de tabela no HIVE
Foram criados alguns scripts para essa automação utilizando notebooks do Zeppelin, pois facilitam o tratamento e os testes na criação das visualizações necessárias. Mas estará disponível também os scripts, caso queiram utilizar através do console SSH, assim como os scripts HQL para uso no Hue ou pelo beeline.

## Configuração do Zeppelin
### Habilitar o menu de interpretadores
Acessar o serviço do Zeppelin no Cloudera Manager e selecionar Configuration. No campo de Busca, procurar por `Urls Block`, após a filtragem das opções, remover a restrição de acesso ao menu de interpretadores, removendo a linha `/api/interpreter/\*\* = authc, roles[{{zeppelin_admin_group}}]`, clicando no ícone da lixeira, no final da caixa de texto.

Após configuração, descrever as alterações no caixa de texto *Reason for Change:*, no final da pagina com o seguinte: **Habilitar o menu de interpretadores**, para facilitar a rastreabilidade de configurações e clicar no botão "Save Changes" para salvar a configuração.

### Habilitar o agendador de tarefas Cron
Aproveitar para habilitar o agendador do Cron no Zeppelin para criar uma coleta agendada diária ou na frequência que julgar necessária. No campo de busca, procurar por *zeppelin-site.xml* e clicando no ícone de mais (Add), adicionar o seguinte parâmetro:

**Name:** zeppelin.notebook.cron.enable

**Value:** true

**Description:** Cron scheduler for zeppelin notebook

Após configuração, descrever as alterações no caixa de texto *Reason for Change:*, no final da pagina com o seguinte: **Habilitar o agendador de tarefas**, para facilitar a rastreabilidade de configurações e clicar no botão "Save Changes" para salvar a configuração.

Fonte: https://zeppelin.apache.org/docs/0.8.0/usage/other_features/cron_scheduler.html

### Habilitar o User impersonation no Zeppelin
Para garantir que as execuções dos scripts sejam feitas por um usuário que tenha privilégios administrativos e que o relatório do HDFS FSCK seja completo, faz-se necessário a configuração do impersonate do usuário. Com o usuário configurado para executar comandos sudo sem senha e fazer parte do grupo supergroup, irá garantir que não haja impacto nas execuções e que o relatório fique completo, entretanto, é necessário a avaliação com o time de segurança para entender os *guardrails* necessários ou limitações de comandos através de lista de comandos para execução do sudo.

Acessar o serviço do Zeppelin no Cloudera Manager e selecionar Configuration. No campo de Busca, procurar por `zeppelin-env`, após a filtragem das opções, adicionar as seguintes linhas na caixa de texto (Efetuar a alteração necessária do usuário, conforme necessidade do seu ambiente):

`export ZEPPELIN_IMPERSONATE_USER=centos`

`export ZEPPELIN_IMPERSONATE_CMD='sudo -H -u ${ZEPPELIN_IMPERSONATE_USER} bash -c '`

Após configuração, descrever as alterações no caixa de texto *Reason for Change:*, no final da pagina com o seguinte: **Habilitar o User impersonation**, para facilitar a rastreabilidade de configurações e clicar no botão "Save Changes" para salvar a configuração.

Fonte: https://zeppelin.apache.org/docs/0.10.0/usage/interpreter/user_impersonation.html

Esperar o sinal de reinício do serviço aparecer ao lado do botão de ação do serviço, ou clicar no botão "Actions" e depois em "Restart". Seguir com o reinício do serviço para garantir a nova configuração e ser possível acessar o menu de interpretadores.

### Links sobre a parte de autenticação e segurança no Zeppelin
Autenticação através do Shiro no Zeppelin: https://zeppelin.apache.org/docs/0.6.0/security/shiroauthentication.html
- Desabilitar o acesso anônimo;
- Configuração de autenticação baseada em lista de usuários; e
- Configuração baseada no LDAP para limitação de acesso por grupo.

Autorização de acesso aos notebooks: https://zeppelin.apache.org/docs/0.6.0/security/notebook_authorization.html

## Criação do interpretador SHELL e configuração do User Impersonation 
Com acesso ao menu de interpretadores, é possível criar o interpretador de bash shell. Para isso, efetuar o login com o Admin, mesmo login do Cloudera Manager e depois acessar o menu "Interpreter", depois clicar no botão "+ Create" e seguir as configurações abaixo:

**Interpreter Name:** sh

**Interpreter group:** Selecionar sh

Definir o instanciamento do interpretador por Usuário e de forma isolada

Depois disso, selecionar o *User Impersonate* e clicar no botão "Save" no final da sessão de configuração do interpretador.

Se listar a pagina até o fim, será apresentado o último interpretador criado.

**OBS.:** Se for necessário utilizar o novo interpretador em algum notebook já criado, será necessário habilitar ou efetuar o "binding" no notebook, clicando no ícone de engrenagem no canto superior direito. Após clicar no ícone, selecionar o interpretador para ficar selecionado "azul" e clicar em "Save".

## Configuração do interpretador do livy para mostrar todo o conteúdo da coluna quando consultada
Ir ao menu de interpretadores e na sessão do interpretador **livy**, retirar a seleção da opção `zeppelin.livy.spark.sql.field.truncate`. Depois clicar no botão "Save" no final da sessão de configuração do interpretador.

## Importando os notebooks no Zeppelin
Após autenticação no Zeppelin, na página inicial será possível observar a sessão de Notebooks o primeiro link é para a importação. Clicando nele será aberto uma janela para carregar o notebook, informando o nome e informando a localização dos notebooks. Abaixo segue uma rápida explicações dos *cadernos* e dos scripts:

[Small_Files_Pro_-_HDFS_FSCK_Extract_and_Load](https://github.com/jscaseiro/HDFSsmallfiles/blob/main/Small_Files_Pro_-_HDFS_FSCK_Extract_and_Load.json) - Caderno com interpretador em shell que executa o HDFS FSCK, coleta a informação gerada, trata para transformá-la em csv e carrega para o HDFS.

[Small_Files_Pro_-_Pyspark_load_csv_to_table](https://github.com/jscaseiro/HDFSsmallfiles/blob/main/Small_Files_Pro_-_Pyspark_load_csv_to_table.json) - Caderno para criar o database e a tabela com as informações em CSV. As tabelas são criadas no formato parquet e através do pyspark.

[Small_Files_Pro_-_Merging_small_files_in_HDFS](https://github.com/jscaseiro/HDFSsmallfiles/blob/main/Small_Files_Pro_-_Merging_small_files_in_HDFS.json) - Caderno para mesclar os arquivos pequenos gerados pelos relatórios do HDFS FSCK e pode ser usado como exemplo para mesclar arquivos pequenos de diretórios stage ou de dados brutos.

Os scripts seguem a mesma função dos cadernos para serem executados no console:

[hdfs_fsck_extract_and_load](https://github.com/jscaseiro/HDFSsmallfiles/blob/main/hdfs_fsck_extract_and_load.sh)

[pyspark_load_csv_to_table](https://github.com/jscaseiro/HDFSsmallfiles/blob/main/pyspark_load_csv_to_table.py)

**OBS.:** Antes de executar o script pyspark para a criação da tabela é necessário criar a database smallfiles no Hive (`CREATE DATABASE IF NOT EXISTS smallfiles;`)