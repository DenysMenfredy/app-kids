# Lelê — Plano de execução para concluir o MVP

**Versão:** 2.0 — assinaturas exclusivas pelas lojas  
**Atualizado em:** 16/10/2026  
**Stack:** Flutter + Firebase Authentication, Firestore, Cloud Functions, Storage e FCM; Google Play Billing no Android e StoreKit/In-App Purchase no iOS.  
**Objetivo:** transformar a implementação atual em um MVP seguro, funcional, comercialmente coerente e pronto para validação com famílias.

## 1. Base do plano e premissas

Este plano usa os cinco grupos de pendências fornecidos pelo responsável pelo projeto. Não houve nova inspeção do repositório nesta elaboração. Os caminhos e os problemas descritos são referências para a execução; o primeiro passo será confirmar o estado atual do código, dos ambientes e dos dados existentes.

- Diretório de referência: `/home/denys7/projects/app-kids`.
- Aplicativo: `lele/`; Firebase/backend: `backend/`.
- Conta autenticada pertence ao responsável; crianças são perfis dependentes dessa conta.
- O MVP suporta criação e seleção de múltiplas crianças, com progresso separado.
- Toda autorização, recompensa, classificação de nível, conclusão e concessão de Premium é decidida pelo backend.
- Segurança, telemetria básica e testes acompanham cada entrega.
- A assinatura pertence à conta do responsável e libera os perfis infantis elegíveis dessa conta; não há cobrança por criança neste plano.
- A compra ocorre exclusivamente na loja da plataforma. O Firebase valida e materializa os direitos de acesso.
- A integração é direta com as APIs das lojas, sem intermediário de gestão de assinaturas no MVP.
- Não entram neste ciclo: tutor de IA, reconhecimento de voz, personalização por IA, competição, moeda virtual com compras ou expansão extensa do currículo.

**Definição de conclusão:** nenhum bloqueador aberto; fluxos completos em staging; evidências em aparelhos Android e iOS; conteúdo anunciado utilizável; decisões comerciais refletidas no produto; procedimento de recuperação validado.

## 2. Escopo de cobrança e decisões de produto

### 2.1. Nomenclatura e arquitetura definidas

Para o conteúdo digital consumido no Lelê, o fluxo será de assinatura dentro do aplicativo:

| Plataforma | Integração de assinatura | Administração | Verificação no backend |
|---|---|---|---|
| Android | Google Play Billing | Google Play Console | Google Play Developer API |
| iOS | In-App Purchase, com StoreKit 2 | App Store Connect | App Store Server API e verificação de dados assinados |

**Google Pay e Apple Pay são carteiras digitais.** Elas não serão implementadas como APIs de checkout para estas assinaturas. A família conclui a compra na interface da loja, usando os meios de pagamento disponibilizados pela própria loja; o app não escolhe nem restringe esses meios às carteiras. Os textos do produto devem dizer “Assinar”, “Google Play” ou “App Store”, sem prometer pagamento via carteira específica.

**Escopo fechado:** aquisição, renovação, cancelamento, restauração e gerenciamento de assinatura pelas lojas. Checkout web, formulário de cartão, gateway externo e portal externo de cobrança ficam fora do projeto. Não será necessário configurar Merchant ID de Apple Pay para este fluxo.

**Autenticação e cobrança são domínios separados:** login com Google/Apple não comprova assinatura, e a conta de compra da loja pode ser diferente do email utilizado no Firebase. Não usar email como vínculo de titularidade da compra.

### 2.2. Decisões a registrar em ADR no início

As recomendações comerciais abaixo continuam sendo propostas. O uso exclusivo de billing nativo já está definido por este plano.

| ID | Decisão | Proposta | Prazo | Efeito |
|---|---|---|---|---|
| D01 | Trial de sete dias | Lançar sem promessa de trial; ativar somente após configurar e validar oferta e elegibilidade em ambas as lojas | Dias 1–2 | Impede oferta enganosa |
| D02 | Fronteira gratuita/Premium | Uma unidade introdutória completa gratuita, com IDs versionados; classificar cada unidade e livro adicional | Dias 1–2 | Permite autorização consistente |
| D03 | Implementação de billing | Integração direta: Flutter `in_app_purchase`, adaptadores de plataforma e validação Firebase | Definida; confirmar compatibilidade em F0 | Billing nativo faz parte da entrega principal |
| D04 | Uso offline | Cache de catálogo/histórico; autorização de conteúdo protegido e conclusão autoritativa exigem conexão no MVP | Dias 1–2 | Define limites de cache e recuperação |
| D05 | Perfil infantil | Nome curto, avatar e faixa etária; nascimento exato somente com necessidade justificada | Dias 1–3 | Minimiza dados |
| D06 | Conteúdo disponível | Manifesto fechado de lições, atividades, histórias e livros realmente utilizáveis | Dias 1–3 | Limita prazo e promessas |
| D07 | Retenção e exclusão | Matriz por categoria, finalidade, prazo, exceção e responsável | Semana 1 | Cobre dados, billing e backups |
| D08 | Acesso entre dispositivos | Mesmo UID Firebase recebe o mesmo Premium em Android/iOS; nova compra só na loja local e se não houver assinatura elegível conhecida | Semana 1 | Reduz dupla cobrança e conflitos de restore |
| D09 | Planos e preços | Mensal, trimestral e anual com os benefícios equivalentes; mudanças de plano durante vigência ficam fora da UI inicial | Semana 1 | Simplifica testes e regras de troca |

Referências comerciais anteriores: mensal R$ 19,90, trimestral R$ 49,90 e anual R$ 149,90. São valores pretendidos para configuração, não strings fixas da interface. Confirmar preços disponíveis por região nas lojas e exibir sempre valor/período localizados retornados pelo catálogo da loja. Não prometer preço vitalício de fundador sem política específica.

### 2.3. Pré-requisitos externos iniciados em F0

- [ ] Google Play Console e Apple Developer/App Store Connect ativos, com contratos, informações bancárias e fiscais necessários concluídos.
- [ ] Apps e produtos cadastrados; responsável por cada console definido.
- [ ] Acesso ao Play Developer API, Pub/Sub, APNs e credenciais da App Store Server API com permissões mínimas.
- [ ] Android físico e iPhone físico disponíveis; Mac/Xcode e assinatura iOS operacional.
- [ ] Testadores de licença/faixa interna Google e usuários sandbox/TestFlight Apple preparados.
- [ ] Revisar políticas atuais de apps infantis, privacidade e assinaturas antes de submissão.

O beta pode ser disponibilizado sem venda apenas para validar aprendizagem. O lançamento comercial exige os dois fluxos de cobrança e seus callbacks reais; não existe uma etapa futura opcional para terminar billing.

## 3. Prioridades, dependências e prazo

**P0:** bloqueio de inicialização, falha de confiança, exposição de dados, concessão indevida de Premium ou risco de cobrança incorreta.  
**P1:** fluxo necessário para a experiência completa de aprendizagem e assinatura.  
**P2:** melhoria posterior sem promessa no lançamento.

**Estimativa inicial: 48–65 dias úteis, aproximadamente 10–13 semanas**, para um desenvolvedor experiente em Flutter/Firebase, com apoio pontual de conteúdo, produto e QA em dispositivos. Billing Android/iOS já está incluído. Recalibrar após F0; não houve inspeção atual do repositório nem medição de produtividade nesta revisão.

| Fase | Entrega | Prioridade | Esforço | Dependências |
|---|---|---|---|---|
| F0 | Inventário, ADRs, consoles, CI e contratos | P0 | 2–3 dias | Acessos e código |
| F1 | Firebase real, App Check e fechamento das brechas | P0 | 5–7 dias | F0 |
| F2 | Contas, múltiplas crianças, identidade e ciclo de dados | P0/P1 | 7–10 dias | F1, D05/D07 |
| F3 | Assinaturas Android/iOS, validação e proteção Premium | P0/P1 | 14–18 dias | F1, identidade de F2, produtos ativos |
| F4 | Conteúdo utilizável, sessões e progresso real | P1 | 7–10 dias | Contratos de F2/F3 e D06 |
| F5 | Push, missões diárias e operação | P1 | 5–7 dias | F2 e dados de F4 |
| F6 | Regressão, piloto e preparação do lançamento | P0/P1 | 8–10 dias | F1–F5 |

Revisões de lojas, aprovação de contas/produtos e produção extensa de conteúdo têm dependências externas; o esforço estimado não garante suas datas. As faixas de cada fase somam 48–65 dias úteis. Não somar outra estimativa de billing ao total.

**Marcos relativos:** dias 1–3, escopo e dependências fechados; dias 8–10, confiança e startup; dias 15–20, identidade/perfis; dias 29–38, billing e Premium; dias 36–48, conteúdo real; dias 41–55, engagement/operação; dias 48–65, piloto e candidato de lançamento.

O início de cada fase depende do aceite anterior; as datas são faixas de planejamento, não compromissos de aprovação das lojas. Telemetria mínima acompanha as primeiras PRs. Configuração dos consoles começa no dia 1 para não bloquear F3.

**Caminho crítico:** startup e confiança → identidade do responsável → vínculo seguro da compra → entitlement → acesso/conclusão protegidos → conteúdo/progresso → missões e lembretes → validação física e comercial.

## 4. F0 — Confirmar o estado e preparar execução

### Tarefas

- [ ] Confirmar os cinco grupos de pendências no código e registrar o que já foi corrigido.
- [ ] Inventariar projetos Firebase, IDs de apps, package/bundle IDs, regiões, regras, índices e secrets.
- [ ] Mapear versões das dependências e comandos reais de lint, análise, testes e build.
- [ ] Registrar D01–D09 e o manifesto de conteúdo do MVP.
- [ ] Inspecionar ADR 0005 e preservar seus requisitos de identidade Apple.
- [ ] Inventariar dados existentes com `childId = primary` e definir migração em staging.
- [ ] Criar backlog com os IDs deste documento, dependências e critérios de aceite.
- [ ] Garantir CI para Flutter, Functions e regras no Emulator Suite.
- [ ] Separar dev/staging/produção e contextos de compra Google test/produção e Apple sandbox/produção. Registrar como TestFlight e contas de review serão tratados sem contaminar relatórios comerciais.

### Aceite

Ambientes e comandos reproduzíveis; decisões com responsáveis; dados legados quantificados; nenhuma migração ou mudança de regra planejada sem considerar a versão instalada do cliente.

## 5. F1 — Fechar bloqueios de inicialização e confiança

### T01 — Configuração Firebase por ambiente e plataforma

**Referência:** `lele/lib/firebase_options.dart`.

- [ ] Substituir o placeholder por configuração gerada e selecionada de forma explícita para dev, staging e produção.
- [ ] Configurar registros nativos Android/iOS, arquivos de configuração e IDs coerentes com cada flavor.
- [ ] Configurar Google e Apple, certificados/fingerprints aplicáveis, capacidades e URLs de retorno.
- [ ] Fazer o build falhar com diagnóstico claro se houver ambiente ausente ou incompatível.
- [ ] Separar configuração pública do app de secrets do servidor; nenhuma chave privada Apple, credencial administrativa ou credencial de serviço Google no cliente.
- [ ] Confirmar que um build release não usa emuladores, endpoints locais nem projeto dev.

**Aceite:** instalar build release de staging em Android e iOS físicos; abrir, autenticar, carregar perfil e concluir uma lição sem exceção de configuração.

### T02 — App Check compatível com as callables

- [ ] Ativar App Check após inicializar Firebase e antes das chamadas protegidas.
- [ ] Configurar Play Integrity no Android e App Attest/DeviceCheck conforme suporte iOS.
- [ ] Usar provider debug apenas em desenvolvimento/testes, com tokens fora de produção.
- [ ] Confirmar enforcement das callables e monitorar falhas de atestação.
- [ ] Tratar rejeição no app sem loop de login ou mensagem enganosa de pagamento.
- [ ] Receber eventos Google por Pub/Sub autenticado e notificações Apple por endpoint HTTP com verificação JWS; eventos de loja não usam App Check do cliente.

**Aceite:** requisição legítima de release funciona em ambas as plataformas; callable sem App Check válido é rejeitada; Auth e autorização continuam obrigatórios.

### T03 — Corrigir recompensa por lição inexistente

**Referência:** `backend/functions/src/learning/complete_lesson.ts`.

- [ ] Validar responsável autenticado e propriedade da criança.
- [ ] Confirmar existência, publicação, versão e acesso à lição.
- [ ] Confirmar elegibilidade no percurso e evidência de execução válida, usando sessões/tentativas segundo o contrato de F4.
- [ ] Rejeitar conclusões inventadas, lições inexistentes, não publicadas, bloqueadas ou de outra criança.
- [ ] Fazer conclusão e recompensa em transação atômica ou mecanismo equivalente de consistência.
- [ ] Usar identidade estável por criança/lição para primeira conclusão; retries e concorrência não geram recompensa extra.
- [ ] Manter timestamps, pontuação, posição no percurso e recompensas calculados no servidor.

**Aceite:** ID arbitrário não cria progresso nem recompensa; duas requisições concorrentes geram uma única recompensa; repetir uma lição válida segue a política documentada.

### T04 — Bloquear campos controlados pelo servidor

**Referência:** `backend/firestore.rules`.

- [ ] Listar os campos protegidos existentes: placement/nível, conclusão, score agregado, rewards, entitlement, role e billing.
- [ ] Definir allowlist de campos editáveis pelo responsável, com validação de tipos e limites.
- [ ] Impedir escrita de campos protegidos em create, update, merge e delete/recreate.
- [ ] Eliminar caminhos alternativos que permitam manipular agregados ou progresso.
- [ ] Autorizar manualmente cada operação privilegiada no backend: Admin SDK não depende das Security Rules.
- [ ] Adicionar testes de regras para usuário anônimo, dono, outro responsável e campos protegidos.

**Gate F1:** startup real validado; IDs arbitrários rejeitados; recompensa idempotente; regras e callables impedem escalada e acesso entre contas.

## 6. F2 — Conta, identidade e dados infantis

### T05 — Criação e seleção de crianças

**Referência:** `lele/lib/features/session/application/child_provider.dart`.

- [ ] Substituir a dependência fixa de `primary` por IDs gerados pelo backend.
- [ ] Implementar lista, criação, seleção, edição dos campos permitidos e remoção de perfil.
- [ ] Definir estados sem criança, carregando, erro, removida e seleção inválida.
- [ ] Usar `(uid, childId)` em providers, queries, cache, lições, tentativas, sessões, recompensas e relatórios.
- [ ] O backend valida ownership em toda operação; nunca confia no `childId` enviado.
- [ ] Ao alternar criança, invalidar estado do percurso e impedir que uma sessão anterior seja atribuída à nova seleção.
- [ ] Migrar `primary` com script idempotente, mapeamento e atualização das referências; ensaiar em staging com cópia de dados de teste.
- [ ] Registrar contagens antes/depois e política de rollback; não duplicar progresso ou recompensas.

**Aceite:** duas crianças na mesma conta têm históricos independentes; duas contas não compartilham nenhum dado; perfil removido não permanece selecionado.

### T06 — Isolamento local ao trocar de conta

- [ ] Fazer cache e perfil local terem namespace por UID e criança.
- [ ] Cancelar listeners e invalidar providers no logout e em mudança de UID.
- [ ] Limpar seleção e referências sensíveis; tratar persistência offline do SDK conforme a estratégia escolhida.
- [ ] Remover fallback que possa exibir perfil de outra conta.
- [ ] Não restaurar perfil anônimo/local para conta autenticada automaticamente; eventual importação exige fluxo explícito e validação.

**Teste obrigatório:** conta A com criança → logout → conta B sem criança → estado vazio; repetir offline e após reinício do aplicativo. Não pode aparecer nome, avatar ou progresso de A.

### T07 — Verificação de email e vinculação de providers

- [ ] Adicionar envio/reenvio de verificação, reload de usuário e atualização do ID token.
- [ ] Definir operações que exigem email verificado e aplicar a exigência no servidor, quando pertinente ao provider.
- [ ] Adicionar fluxo explícito de vinculação com reautenticação da conta atual.
- [ ] Tratar credencial já vinculada e conta existente sem fundir contas silenciosamente por email.
- [ ] Implementar o prompt de possível duplicação com Apple conforme ADR 0005, incluindo email privado e ausência de nome/email em logins posteriores.
- [ ] Testar login, logout, reset de senha, cancelamento de SSO e falha de rede.
- [ ] Documentar procedimento assistido para conflitos que não podem ser resolvidos pelo fluxo de linking.

**Aceite:** vinculação suportada mantém UID e dados; duplicação Apple tem orientação acionável; não há acesso a outra conta baseado somente na coincidência de email.

### T08 — Consentimento, exclusão e retenção

- [ ] Exibir consentimento do responsável antes da criação/coleta de dados infantis.
- [ ] Registrar versão do texto, finalidade, UID e timestamp do servidor; evitar dados adicionais sem necessidade.
- [ ] Separar opções de notificações, marketing e analytics quando aplicável à política adotada.
- [ ] Implementar exclusão com reautenticação e operação durável, idempotente e acompanhável.
- [ ] Bloquear novas operações, agendamentos e início de compras durante a exclusão.
- [ ] Mostrar loja de origem e acesso ao gerenciamento/cancelamento antes da exclusão. Explicar que apagar a conta não cancela automaticamente a renovação na loja; não impedir indefinidamente a exclusão por haver assinatura ativa. Definir suporte para falhas de cancelamento e retenção mínima dos vínculos financeiros.
- [ ] Revogar sessões/tokens, encerrar dispositivos, remover dados de crianças e arquivos e percorrer subcoleções explicitamente.
- [ ] Aplicar a exclusão a filas, relatórios, exportações e identificadores em analytics conforme matriz D07.
- [ ] Tratar callbacks tardios de pagamento sem recriar conta/perfil excluído; conservar só o mínimo necessário para reconciliação autorizada.
- [ ] Definir expiração de backups e reaplicar exclusões após restore antes de reabrir acesso.
- [ ] Publicar política de privacidade/retenção revisada para o público infantil e manter canal de solicitação/exportação.

**Aceite:** exclusão ponta a ponta ensaiada em staging, inclusive falha intermediária e retomada; matriz de retenção cobre Firestore, Auth, Storage, billing, logs, analytics, backups e filas.

## 7. F3 — Assinaturas nativas e acesso Premium

### 7.1. Arquitetura do domínio

| Camada | Responsabilidade |
|---|---|
| Flutter | Catálogo da loja, tela de compra, listener, restore e estado visual |
| `BillingRepository` | Contrato comum de planos, aquisição e restauração |
| Adaptadores Android/iOS | Campos de loja, identificadores de conta e conclusão de transação |
| Callable Firebase | Validar Auth/App Check, identidade e evidência da compra |
| Adaptadores backend | Consultar/verificar Google Play e Apple |
| Processador de eventos | Recepção durável, deduplicação e reconciliação |
| Firestore | Projeção de assinatura e entitlement somente de escrita do servidor |
| Regras/API/Storage | Aplicar acesso gratuito/Premium em conteúdo e mídias |

O fluxo de aquisição é: responsável autenticado → catálogo da plataforma → confirmação nativa → evidência enviada ao Firebase → verificação na loja → gravação idempotente → liberação de acesso → acknowledgement/finalização conforme a plataforma. O evento recebido pelo app, isoladamente, nunca concede Premium.

Renovações e cancelamentos chegam ao backend sem exigir abertura do app: Google RTDN/Pub/Sub e App Store Server Notifications V2 alimentam o mesmo serviço de reconciliação. Chamadas do cliente aceleram a primeira ativação e a restauração; não são a única fonte de atualização.

### T09 — Produtos, oferta e paywall

**Referência:** `lele/lib/features/paywall/presentation/paywall_screen.dart`. Localizar e substituir o módulo atual de pagamento durante F0; os nomes abaixo são contratos propostos, não arquivos já existentes.

- [ ] Criar `premium` como benefício interno único e mapear os produtos de cada loja.
- [ ] Android: proposta de uma subscription `lele_premium` com base plans `monthly`, `quarterly` e `annual`; confirmar IDs finais no console antes de codificar.
- [ ] iOS: um subscription group Premium, com produtos mensal, trimestral e anual no mesmo nível de serviço.
- [ ] Persistir allowlist server-side de package/bundle, produto, base plan/oferta, ambiente e benefício.
- [ ] Carregar catálogo da loja por plataforma; não inventar preço se o produto estiver indisponível.
- [ ] Exibir preço localizado, periodicidade, renovação, benefícios, termos, privacidade, “Restaurar compras” e “Gerenciar assinatura”.
- [ ] Implementar paywall e entrada de compra na área do responsável, com barreira parental apropriada; não usar tarefa de leitura inacessível como único controle infantil.
- [ ] Aplicar D01: remover copy de sete dias se não houver trial configurado e elegível.
- [ ] Se trial for escolhido, configurar oferta introdutória em cada loja e derivar elegibilidade/condições da loja; Firebase não inventa trial comercial paralelo.
- [ ] Não mostrar oferta gratuita para usuário inelegível; informar preço e período após o trial quando houver.
- [ ] Definir limite de perfis por conta, se houver; refletir limite e benefícios na oferta.

**Aceite:** catálogo real em ambos os sistemas; produto indisponível não é vendido; oferta coincide com a confirmação nativa; nenhuma promessa de conteúdo ausente ou trial inexistente.

### T10 — Proteção free/Premium e política de acesso

- [ ] Versionar o conjunto de conteúdo gratuito e classificar cada lição/livro publicado.
- [ ] Separar metadados de catálogo do payload e mídia protegidos.
- [ ] Validar autenticação, ownership infantil, publicação e entitlement no carregamento, início e conclusão.
- [ ] Fazer queries Firestore compatíveis com as regras; regras não filtram resultados automaticamente.
- [ ] Usar callable para payload protegido quando necessário, fechando o acesso direto equivalente.
- [ ] Proteger Storage e evitar URLs permanentes de download que contornem autorização.
- [ ] Definir expiração de URLs/cache; não prometer revogação de bytes já baixados.
- [ ] Entitlement desconhecido ou falha de rede não equivalem a Premium.
- [ ] Proposta: uma sessão autorizada pode terminar apenas dentro de uma janela curta definida pelo servidor; nova sessão exige direito vigente. Fixar a janela em ADR e testar expiração/revogação.
- [ ] Desabilitar nova aquisição se o backend já conhece assinatura elegível na conta, inclusive de outra plataforma; mostrar a loja de origem.
- [ ] Manter servidor como autoridade para validade, features e limite de perfis.

**Aceite:** conta free acessa só o conjunto definido; requests diretos, deep links e mídia não contornam a proteção; Premium confirmado funciona em ambos os sistemas para o mesmo UID, conforme D08.

### T11 — Verificação, vínculo de conta e lifecycle no Firebase

#### Android — Google Play

- [ ] Receber `purchaseToken`, produto e contexto como evidência não confiável; obter package e allowlist do servidor.
- [ ] Consultar `purchases.subscriptionsv2.get` com credencial de serviço autorizada.
- [ ] Verificar produto/base plan, ambiente de teste quando aplicável, estado, validade e identidade ofuscada associada.
- [ ] Gerar identificador opaco do responsável no backend e passá-lo como `obfuscatedAccountId`, conforme API suportada pelo adaptador Flutter.
- [ ] Não usar email nem `orderId` como identidade canônica da compra; manter vínculo único do token e suas relações de substituição.
- [ ] Processar `linkedPurchaseToken` para continuidade de assinatura e impedir duplicação de entitlement.
- [ ] Rejeitar concessão enquanto compra estiver pendente; aprovação precisa ser confirmada na loja.
- [ ] Após persistir a concessão legítima, realizar acknowledgement server-side prontamente; manter retry durável e alerta. Não depender do usuário reabrir o app para confirmar compra.
- [ ] Tratar prazo exigido de acknowledgement e janelas aceleradas de teste; definir meta interna muito menor que o limite da loja.
- [ ] Configurar RTDN em Pub/Sub com IAM/autenticação apropriados. Se push HTTP for utilizado, validar identidade, audience e origem esperadas.
- [ ] RTDN sinaliza mudança; consultar a API para obter o estado completo antes de atualizar acesso.

#### iOS — App Store

- [ ] Usar evidência compatível com StoreKit 2 e consultar/verificar transações via App Store Server API/biblioteca oficial.
- [ ] Validar JWS/cadeia de certificados com biblioteca apropriada; decodificar JSON não verifica assinatura.
- [ ] Verificar bundle ID, app Apple ID onde exigido, ambiente, produto, expiração e revogação.
- [ ] Gerar `appAccountToken` opaco em formato aceito pela Apple e mapear exclusivamente ao UID Firebase; validar associação no servidor.
- [ ] Inspecionar no spike se a versão do plugin expõe `appAccountToken` e dados StoreKit 2 necessários; usar extensão/adaptador nativo se faltar suporte, sem substituir a validação por confiança no cliente.
- [ ] Usar `originalTransactionId` para continuidade da assinatura e `transactionId` para cada transação.
- [ ] Configurar Notifications V2 para sandbox e produção; verificar notificação e dados assinados internos antes de processar.
- [ ] Finalizar transação no app após validação e persistência do benefício; recuperar transações não finalizadas no próximo início.
- [ ] Tratar Ask to Buy/aprovação pendente sem acesso antecipado.

#### Regras comuns

- [ ] Exigir sessão Firebase do responsável para iniciar aquisição/restore; não confundir usuário Firebase com usuário da loja.
- [ ] Fazer associação de titularidade em transação com índice único global por identidade de compra; outra conta não pode tomar uma compra já vinculada.
- [ ] Identificadores enviados pelo app são pistas: só têm valor após verificação junto à loja e cruzamento com o vínculo server-side.
- [ ] Em restore que conflita com outra conta, não transferir automaticamente; orientar login na conta original ou suporte com prova apropriada.
- [ ] Eventos de compra sem conta conhecida entram em pendência de reconciliação; não criar usuário a partir de email ou payload da loja.
- [ ] Persistir evento/inbox antes de confirmar recebimento; projetar processamento idempotente, retry e fila de falhas.
- [ ] Deduplicar evento e transação; reconciliar estado atual e serializar por assinatura para lidar com callbacks fora de ordem.
- [ ] Projetar subscription e entitlement de forma consistente; notificação de UI/analytics sai por outbox, sem conceder duas vezes.
- [ ] Executar reconciliação periódica de assinaturas próximas da expiração, falhas e notificações pendentes, com orçamento de API.
- [ ] Separar teste e produção por contexto verificado; documentar como review/TestFlight acessam ambiente de teste sem bloquear avaliação ou gerar receita fictícia.
- [ ] Registrar `lastVerifiedAt`, motivo da decisão e origem verificada; omitir tokens, JWS completos e PII dos logs.
- [ ] Conta em exclusão não é recriada por callback tardio.

#### Política normalizada de estados

Esta é uma projeção interna proposta. Cada adaptador precisa mapear os estados reais da sua loja e conservar os campos originais necessários à reconciliação.

| Estado interno | Conceder acesso? | Regra |
|---|---|---|
| `pending` / `verification_pending` | Não conceder acesso novo | Aguardar prova confirmada; não encerrar outro direito válido por falha transitória |
| `trialing` | Sim | Oferta e prazo confirmados pela loja |
| `active` | Sim | Até o limite de validade verificado |
| `grace_period` | Sim, se confirmado | Somente até `graceUntil` confirmado, sem inventar prazo |
| `billing_retry` / `on_hold` | Não por este estado isolado | Manter somente outro direito ou grace ainda válido |
| `canceled` com período vigente | Sim | Cancelamento de renovação não elimina período já adquirido |
| `paused` em vigor | Não | Diferenciar pausa futura de pausa já efetiva |
| `expired` | Não | Direito encerrado |
| `revoked` | Não para a fonte revogada | Reavaliar imediatamente; não retirar outra fonte válida |

**Teste obrigatório:** compra ou callback real de sandbox → verificação confiável → subscription → entitlement → autorização de lição Premium. Incluir fraude, conflito entre UIDs, duplicatas, falha parcial, callbacks invertidos, renovação, grace, hold, cancelamento, expiração e revogação.

### T12 — Flutter: aquisição, conclusão, restore e gerenciamento

- [ ] Usar `in_app_purchase` com versão estável compatível com o repositório e requisitos atuais das lojas; fixar versão testada.
- [ ] Implementar `BillingRepository` testável e adaptadores para campos específicos de Android/iOS.
- [ ] Escutar `purchaseStream` cedo e recuperar atualizações anteriores ao abrir o app.
- [ ] Modelar estados: catálogo carregando, disponível, indisponível, comprando, pendente, verificando, ativo, cancelado pelo usuário, erro recuperável e conflito de conta.
- [ ] Evitar chamadas de compra concorrentes; persistir operação pendente vinculada ao responsável original e não atribuí-la ao UID que entrou depois.
- [ ] Ao receber purchase/restored, enviar evidência à callable, aguardar a confirmação server-side e atualizar entitlement.
- [ ] Em queda de rede após compra, mostrar “Estamos confirmando sua assinatura”, retomar verificação e oferecer restauração; não iniciar nova cobrança para recuperar a primeira.
- [ ] Separar concessão de benefício de finalização: coordenar acknowledgement Android no backend e `completePurchase`/finish no adaptador conforme a plataforma, idempotentemente.
- [ ] Não consumir assinatura como produto consumível nem simular falha de pagamento quando o usuário cancela a folha nativa.
- [ ] Implementar restauração explícita e sincronização ao login/retorno do app; reenviar evidência para validação, sem conceder acesso só pelo listener.
- [ ] Abrir gerenciamento de assinatura da loja de origem; no dispositivo oposto, orientar gerenciamento na plataforma original com link oficial quando adequado.
- [ ] Compra Apple não é restaurada pela API Google e vice-versa; o acesso entre plataformas decorre do entitlement da mesma conta Firebase.
- [ ] Garantir barreira parental para aquisição/gerenciamento e navegação externa, conforme distribuição infantil.
- [ ] Ocultar mudanças de plano em vigor na primeira versão; ainda assim reconciliar mudanças feitas pela loja, inclusive substituição de token/produto.

**Gate F3:** compra, renovação, cancelamento, expiração, restauração e recuperação de falhas demonstrados nas duas lojas; conteúdo protegido; nenhuma ativação baseada apenas no cliente; operações de confirmação/finalização monitoradas.

## 8. F4 — Conteúdo completo e progresso verdadeiro

### T13 — Histórias e compreensão

- [ ] Adicionar contrato versionado para história: páginas, texto, imagens, áudio opcional e perguntas de compreensão.
- [ ] Implementar apresentação, navegação, resposta, feedback e encerramento.
- [ ] Integrar ao motor de lições sem quebrar os quatro tipos de exercícios existentes.
- [ ] Validar seed/manifesto para impedir publicar tipo não suportado, resposta ausente ou mídia inválida.
- [ ] Fazer cada história anunciada ser executável até a conclusão.

### T14 — Biblioteca carregada do backend

- [ ] Substituir catálogo hardcoded por metadados publicados e conteúdo autorizado.
- [ ] Carregar capa, páginas, mídia e classificação free/Premium reais.
- [ ] Implementar estados loading, erro, vazio, indisponível e bloqueado.
- [ ] Persistir posição de leitura por criança; favorites só entram se já estiverem no escopo anunciado.
- [ ] Ocultar conteúdo não publicável; não exibir livro sem páginas como benefício disponível.

### T15 — Tentativas, sessões e conclusão

- [ ] Definir contrato canônico por responsável/criança, com sessão, versão da lição, atividade e request ID.
- [ ] Criar/validar sessões no backend e registrar respostas com deduplicação.
- [ ] Validar que atividade pertence à sessão/lição, sequência é admissível e criança pertence ao responsável.
- [ ] Calcular correção a partir do conteúdo confiável; não aceitar `correct`, score ou recompensa do cliente como verdade.
- [ ] Para tracing, definir critérios mínimos e limites plausíveis; documentar limitações da evidência enviada pelo cliente.
- [ ] Tratar pausa, retorno, abandono e retry de rede sem duplicar tempo ou conclusão.
- [ ] Contar tempo ativo com limites plausíveis; manter hora recebida pelo servidor e timezone IANA para o dia pedagógico.
- [ ] Integrar estas evidências com `completeLesson` e proteger todos os agregados contra escrita direta.

### T16 — Resumos e gráfico semanal reais

- [ ] Definir fórmulas para lições, tempo ativo, precisão e meta diária; declarar denominadores e janela temporal.
- [ ] Materializar agregados por criança/dia/semana no backend, com atualização idempotente ou recomputação segura.
- [ ] Substituir dados de exemplo do gráfico por esses agregados.
- [ ] Mostrar estados sem dados, primeira semana e falha de atualização.
- [ ] Tratar timezone e sessões próximas da meia-noite sem contar a mesma atividade duas vezes.
- [ ] Validar somas contra conjunto controlado de sessões/tentativas.

**Gate F4:** toda entrada publicada do manifesto é utilizável; tentativas e sessões alimentam progresso; gráfico semanal bate com dados de teste; nenhuma tela de produção exibe estatística de exemplo.

## 9. F5 — Engagement e operação

### T17 — FCM e preferências no Flutter

- [ ] Pedir permissão em contexto explicativo ao responsável; app continua utilizável se houver recusa.
- [ ] Configurar push Android/iOS, APNs e comportamento foreground/background.
- [ ] Registrar installation/device ID, token, plataforma e estado de permissão via backend validado.
- [ ] Atualizar token em refresh e revalidar vínculo no login.
- [ ] No logout/troca de conta, desvincular instalação do responsável anterior; token compartilhado não pode receber mensagens das duas contas.
- [ ] Remover tokens inválidos e evitar duplicação por dispositivo/token.
- [ ] Criar preferências de lembrete, horário local, timezone, relatórios, conquistas e marketing separado.
- [ ] Deep link deve autenticar e selecionar contexto válido; evitar dados infantis sensíveis no push/lock screen.

### T18 — Lembrete baseado em missão diária existente

**Referência:** `backend/functions/src/notifications/send_daily_reminders.ts`.

- [ ] Definir missão diária por criança, com `localDate`, `lessonId`, timezone, status e horário de envio.
- [ ] Criar missão apenas para conteúdo publicado, elegível e acessível; não agendar lembrete para uma lição bloqueada por assinatura.
- [ ] Enviar somente se a missão existe, está pendente/em andamento, preferência permite e horário local é elegível.
- [ ] Revalidar conclusão e consentimento/preferências imediatamente antes de enviar.
- [ ] Consultar agendamentos vencidos com índice e paginação, sem varrer todos os usuários a cada ciclo.
- [ ] Deduplicar por responsável/tipo/dia; consolidar filhos pendentes em um lembrete conforme política definida.
- [ ] Reagendar após mudança de horário/timezone; limitar tentativas e respeitar janela de silêncio.
- [ ] Registrar resultado sem expor token ou dados infantis; diferenciar aceitação pelo FCM de entrega comprovada.
- [ ] Reconhecer que envio externo não é atomicamente transacional: usar claim/outbox, retry controlado e deduplicação no cliente quando aplicável.

**Aceite:** sem missão → sem lembrete; missão concluída → sem lembrete; pendente elegível → envio; preferência desativada/conta excluída → sem envio; concorrência e retries têm comportamento testado e limitado.

### T19 — Analytics e Crashlytics

- [ ] Instrumentar login/onboarding, criação de criança, sessão, tentativa, conclusão, paywall, início de compra nativa, compra pendente, compra confirmada, restore e abertura de notificação.
- [ ] Definir schema, versão, origem e request/session IDs; usar backend como fonte de compra, recompensa e conclusão confirmadas.
- [ ] Evitar dupla contagem entre evento cliente e servidor; diferenciar intenção de resultado.
- [ ] Não enviar nome, email, resposta livre, token, áudio ou identificador pessoal infantil para logs/analytics.
- [ ] Validar estratégia de identificação, consentimento e elegibilidade de Analytics/Crashlytics para a distribuição infantil antes de ativar coleta em produção.
- [ ] Validar eventos em staging e crash não fatal/fatal com símbolos legíveis, sem derrubar produção.
- [ ] Configurar exportação necessária, IAM, retenção, limites de custo e métricas de retenção/conversão com população e janela explícitas.

### T20 — Alertas, backups e restore

- [ ] Configurar logs estruturados com correlação e redaction de dados sensíveis.
- [ ] Alertar falhas de startup/App Check, verificação nas lojas, acknowledgement Android atrasado, transações iOS não finalizadas, eventos pendentes, divergência de entitlement, jobs e custos.
- [ ] Definir responsável e ação para cada alerta; validar entrega do alerta em staging.
- [ ] Configurar backups de Firestore e estratégia para arquivos Storage, Auth e configurações necessárias; um backup do Firestore não cobre todo o sistema.
- [ ] Versionar regras, índices e código; documentar recuperação de configuração e secrets sem expô-los.
- [ ] Proposta de metas operacionais do MVP: RPO ≤ 24 horas e RTO ≤ 8 horas; confirmar viabilidade/custo e medir no ensaio.
- [ ] Restaurar em ambiente isolado; checar amostra e contagens, reprocessamento de exclusões, integridade de referências e reconciliação de billing.
- [ ] Desativar envios/cobranças/jobs no restore de teste para não atingir famílias.
- [ ] Documentar runbooks para evento de loja atrasado, compra cobrada sem acesso, falha de push, perda de dados e rollback de release.

**Gate F5:** push validado nos dois sistemas, lembrete condicionado a missão existente, telemetria observável e restore com resultado e tempos registrados.

## 10. Contrato mínimo de armazenamento a fechar em F0

Os caminhos abaixo são propostas canônicas. Adaptar aos nomes existentes após inspeção; não criar uma segunda fonte de verdade. Subcoleções infantis substituem qualquer progresso ambíguo no nível do responsável.

| Caminho lógico | Dados principais | Escrita autoritativa |
|---|---|---|
| `users/{uid}` | Perfil do responsável e estado da conta | Cliente somente campos permitidos; lifecycle pelo servidor |
| `users/{uid}/children/{childId}` | Perfil, faixa etária, placement e percurso | Backend; edição restrita do perfil |
| `users/{uid}/children/{childId}/sessions/{id}` | Lição/versão, início, atividade, encerramento | Backend |
| `users/{uid}/children/{childId}/activityAttempts/{id}` | Resposta limitada, atividade, correção, request ID | Backend |
| `users/{uid}/children/{childId}/learningProgress/{lessonId}` | Conclusão, score e primeira recompensa | Backend |
| `users/{uid}/children/{childId}/dailyMissions/{localDate}` | Lição elegível e status diário | Backend |
| `users/{uid}/children/{childId}/dailySummaries/{localDate}` | Tempo, acertos, tentativas e lições | Backend |
| `users/{uid}/subscriptions/{id}` | Provider, produto, estado confirmado, vigência e renovação; sem token bruto | Backend |
| `billingPurchaseOwners/{purchaseKey}` | Vínculo único e atômico entre compra verificada e UID | Backend; sem leitura cliente |
| `billingPrivatePurchases/{purchaseKey}` | Tokens/referências necessários à consulta da loja, ambiente e relação de substituição | Backend; sem leitura cliente |
| `billingAccountLinks/{uid}` | Identificadores opacos por loja, vinculados ao responsável | Backend; exposição mínima por callable |
| `users/{uid}/entitlements/premium` | Política, validade e fontes elegíveis | Backend |
| `users/{uid}/devices/{id}` | Token, instalação e vínculo | Backend via registro autenticado |
| `users/{uid}/notificationPreferences/default` | Categorias, horário e timezone | Cliente validado ou callable |
| `users/{uid}/consents/{id}` | Versão/finalidade e registro de consentimento | Backend |
| `billingEvents/{provider_eventId}` | Recepção, processamento, tentativas e resultado | Backend; sem leitura cliente |
| `scheduledNotifications/{id}` | Horário UTC, tipo, claim e resultado | Backend; sem leitura cliente |
| `deletionJobs/{id}` | Estado, etapas, retry e dados mínimos | Backend; status público separado |
| Catálogo/lessons/books | Metadados publicados, versão e acesso | Backend/admin autorizado |
| Payloads e mídias protegidos | Conteúdo pedagógico e arquivos | Backend; leitura autorizada |

**Regras comuns:** timestamps do servidor; schema versionado; duração/score derivados; timezone IANA; valores monetários inteiros na menor unidade da moeda; IDs idempotentes; nenhuma senha, cartão ou secret em documento de aplicação. Planejar índices antes das queries e política de TTL/limpeza por coleção.

### 10.1. Projeção pública de assinatura e dados privados

Exemplo conceitual, a adaptar ao contrato real. Firestore deve usar timestamps tipados; as datas abaixo apenas tornam o exemplo legível. `amount` não é necessário para autorização. Analytics de receita exige tratamento próprio de moeda, impostos, testes e receita líquida das lojas.

```json
{
  "provider": "google_play",
  "internalPlan": "premium_annual",
  "productId": "lele_premium",
  "basePlanId": "annual",
  "status": "active",
  "accessUntil": "2027-10-16T14:00:00Z",
  "graceUntil": null,
  "autoRenewEnabled": true,
  "lastVerifiedAt": "2026-10-16T14:00:00Z",
  "environment": "production",
  "schemaVersion": 1
}
```

No adaptador Apple, usar `provider = apple_app_store` e produto correspondente; `basePlanId` não se aplica. No entitlement, registrar features, fontes elegíveis, validade e revisão de política. O direito pertence ao UID responsável e é consultado para cada operação infantil.

Guardar token de compra e referências de reconciliação somente em coleção privada ao servidor; nunca na projeção que o app pode ler. Derivar `purchaseKey` de identidade verificada com namespace de provider/ambiente/app e hash quando apropriado. Não expor compra em URL, log ou Analytics. Hash é índice, não criptografia nem prova de titularidade.

### 10.2. Contratos propostos de Functions

| Operação | Entrada/ação | Segurança |
|---|---|---|
| `preparePurchase` | Plano permitido → identificador opaco e contexto de compra | Auth, App Check, responsável elegível |
| `verifyGooglePurchase` | Evidência Google → consulta e reconciliação | Auth/App Check + vínculo + API da loja |
| `verifyApplePurchase` | Evidência Apple → verificação e reconciliação | Auth/App Check + vínculo + assinatura/API |
| `getCurrentEntitlements` | Projeção atual de direitos | Auth; sem exposição de tokens |
| `onGoogleRtdn` | Evento Pub/Sub → consulta e reconciliação | IAM/autenticação do transporte |
| `appleServerNotifications` | Notifications V2 → verificação e reconciliação | JWS e identidade do app/ambiente |
| `reconcileSubscriptions` | Revisar estados pendentes e vencimentos | Scheduler/identidade de serviço |
| `processBillingOutbox` | Retry de acknowledgement e efeitos derivados | Identidade de serviço, idempotência |

Aplicar limites de requisição e de tamanho, schema validation e mensagens de erro acionáveis. A mesma função de domínio deve processar aquisição, restore e eventos das lojas para evitar regras divergentes.

### 10.3. Retirada da integração antiga

- [ ] Inventariar endpoints, classes, variáveis, secrets, dependências, telas e testes do gateway anterior.
- [ ] Confirmar se existem assinaturas ou clientes reais antes de desativar qualquer recurso remoto.
- [ ] Se não houver clientes reais, remover o módulo antigo, exports de Functions, checkout, portal e configurações após validar as lojas em staging.
- [ ] Se houver assinantes reais, abrir plano separado de encerramento/migração com comunicação e proteção contra dupla cobrança; uma assinatura externa não se converte automaticamente em assinatura de loja.
- [ ] Bloquear novas aquisições pelo caminho antigo e remover os acessos da UI no release nativo.
- [ ] Desativar credenciais/endpoints legados de modo controlado, após tratar obrigações e reconciliação; não apagar registros que precisem de retenção.
- [ ] CI deve impedir retorno de dependência/rota/configuração de gateway externo no novo app.

Esta tarefa planeja a remoção técnica, sem autorizar cancelamento destrutivo de contratos reais sem inventário e tratamento dos usuários afetados.

## 11. F6 — Matriz de validação e piloto

### Regressões obrigatórias

| Área | Cenário | Resultado esperado |
|---|---|---|
| Startup | Release staging Android/iOS | Firebase e App Check inicializados; nenhuma configuração placeholder |
| Auth | Email, Google e Apple nas plataformas suportadas | Login/relogin consistente e erro acionável |
| Identidade | Linking e conflito Apple | UID preservado quando vinculado; conflito sem merge inseguro |
| Conta | A → logout → B sem criança, online/offline | Nenhum perfil ou progresso de A aparece |
| Crianças | Duas crianças, alternância durante atividade | Sessão e recompensa ficam no perfil original |
| Ownership | Outra conta tenta acessar child/session | Rejeição no backend e nas regras |
| Confiança | Escrita direta de placement/completion | Rejeição em todos os caminhos |
| Recompensa | ID inventado e conclusão concorrente | Nenhuma recompensa inválida; uma recompensa válida |
| Premium | Query, ID direto, Storage e deep link gratuitos | Conteúdo protegido inacessível |
| Oferta | Trial desativado ou elegibilidade real da loja | Copy, catálogo e confirmação nativa coincidem |
| Billing Android | Compra validada pela API e evento RTDN autenticado | Concessão correta e acknowledgement registrado |
| Billing iOS | Transação verificada e Notifications V2 válidas | Concessão correta e finalização sem loop |
| Billing | Evento repetido, fora de ordem e falha parcial | Convergência e recuperação sem duplicação |
| Titularidade | Outra conta tenta restaurar token/transação já vinculada | Conflito tratado sem transferência automática |
| Restore | Reinstalar e entrar no mesmo UID em outro aparelho | Compra validada e acesso recuperado |
| Entre plataformas | Conta comprou em uma loja e entra na outra | Acesso pelo entitlement; compra duplicada desestimulada |
| Rede | Loja cobrou, app fechou antes da confirmação | Recuperação sem nova cobrança nem perda do direito |
| Conteúdo | História, livro e exercícios existentes | Início, resposta/feedback e encerramento completos |
| Progresso | Retry de tentativa e sessão pausada | Sem dupla contagem; resumo verificável |
| Push | Token refresh e troca de conta | Vínculo atual; nenhum envio ao responsável anterior |
| Lembrete | Missão ausente/concluída versus pendente | Envio somente na situação definida |
| Exclusão | Falha parcial e notificação de loja tardia | Job retoma; conta não reaparece |
| Recuperação | Restore isolado e reconciliação | Dados íntegros, exclusões respeitadas e tempos medidos |

Executar testes unitários para políticas e cálculos; integração com emuladores para regras e transações; Google Play internal testing/license testers e Apple StoreKit testing/sandbox/TestFlight para billing; testes de UI para isolamento e navegação. StoreKit local e mocks não substituem callbacks e verificação real de sandbox. App Check, SSO, APNs e release exigem validação física além dos emuladores.

### Piloto proposto

- [ ] Selecionar 5–10 responsáveis convidados, com consentimento e canal de feedback definido.
- [ ] Executar uma primeira rodada de uso por pelo menos sete dias, cobrindo cadastro, seleção e missão diária.
- [ ] Medir falhas, abandono e entendimento do paywall; registrar feedback sobre conteúdo e leitura das instruções.
- [ ] Priorizar crashes, vazamento entre contas, acesso indevido, cobrança incorreta e bloqueio de progresso antes de ajustes visuais.
- [ ] Repetir apenas fluxos afetados pelas correções e smoke test completo do candidato final.

O piloto de sete dias não mede churn mensal ou retenção D30. Metas de crescimento e receita devem orientar ciclos posteriores; não substituem gates técnicos ou funcionais de lançamento.

## 12. Gates de entrega

### G1 — Beta técnico interno

- [ ] F1 concluída, teste de isolamento de F2 aprovado e fluxo mínimo por criança estável.
- [ ] Contas e dados de teste separados de produção.
- [ ] Nenhum P0 de confiança, startup ou privacidade aberto.

### G2 — MVP para famílias convidadas

- [ ] F1–F5 aprovadas para o escopo do beta e manifesto integralmente utilizável; F3 pode ser exercitada em sandbox, com aquisição real desativada até G3.
- [ ] Consentimento, exclusão, retenção e políticas revisados.
- [ ] Analytics/Crashlytics configurados conforme decisão de coleta.
- [ ] Backup, restore e alertas demonstrados.
- [ ] Compra desabilitada se a via de billing escolhida ainda não estiver pronta.

### G3 — Lançamento comercial móvel

- [ ] G2 aprovado e billing permitido implementado e testado em cada plataforma.
- [ ] Oferta, trial, planos, cancelamento, restore e gerenciamento coerentes por loja; callback real de cada provider validado.
- [ ] Toda promessa de paywall corresponde a conteúdo e funcionalidade disponíveis.
- [ ] Requisitos atuais de distribuição infantil, dados e cobrança revisados; formulários de privacidade/Data Safety e classificação etária preenchidos; conta e instruções de review disponíveis.
- [ ] Nenhum P0/P1 aberto neste escopo; release e rollback documentados.
- [ ] Build candidato validado em Android/iOS reais; review das lojas acompanhado separadamente.

## 13. Organização das entregas e rotina com Claude Code

Fazer PRs pequenas por comportamento, com dependências explícitas. Não misturar migração de dados, mudança de regras e novo fluxo de billing em uma única entrega difícil de reverter.

Sequência sugerida de pacotes:

1. **PR01:** inventário, ADRs, contrato de dados e CI.
2. **PR02:** Firebase por ambiente + App Check + smoke tests físicos.
3. **PR03:** correção de `completeLesson` + regras + regressões de confiança.
4. **PR04:** contratos multi-child, migração e isolamento de conta/cache.
5. **PR05:** UI de perfis, verificação de email e linking/Apple ADR 0005.
6. **PR06:** consentimento, jobs de exclusão e retenção.
7. **PR07:** classificação/proteção de conteúdo, contrato de billing, catálogo e paywall nativo.
8. **PR08:** Google Play Billing, validação backend, RTDN e acknowledgement.
9. **PR09:** StoreKit 2, validação Apple, Notifications V2 e restore/gerenciamento nas duas plataformas.
10. **PR10:** histórias e biblioteca real.
11. **PR11:** sessões/tentativas, conclusão validada e resumos reais.
12. **PR12:** FCM, preferências e missões/lembretes.
13. **PR13:** observabilidade completa, backup/restore e runbooks.
14. **PR14:** correções do piloto e checklist do release.

Adicionar instrumentação mínima às PRs relevantes desde PR02. A ordem pode adaptar contratos de sessões antecipadamente para PR03; a recompensa não deve esperar o final do ciclo para ficar protegida.

### Template de tarefa

```markdown
## [Txx] Comportamento a entregar

Prioridade:
Dependências:
Responsável:
Estimativa:

### Problema e comportamento esperado

### Contratos, campos protegidos e migração

### Implementação
- [ ] Backend
- [ ] Flutter
- [ ] Rules/Storage/IAM
- [ ] Telemetria

### Aceite
- [ ] Cenário funcional
- [ ] Cenário de abuso/isolamento aplicável
- [ ] Retry/concorrência aplicável

### Evidências
- Testes e resultado:
- Ambiente/build:
- Dispositivo, quando aplicável:
- Rollout/rollback:
```

### Instrução para cada ciclo de implementação

```text
Execute apenas a tarefa e as dependências indicadas. Primeiro confirme o estado
atual no código e nos ADRs. Reutilize os contratos existentes e evite fontes
paralelas de verdade. Nunca aceite do cliente autorização, entitlement,
placement, completion, score agregado ou recompensa como estado confiável.
Valide ownership no backend mesmo usando Admin SDK. Adicione as regressões
necessárias, execute os checks reais do repositório e informe mudanças,
evidências, limitações e pendências. Use exclusivamente billing nativo Google
Play/App Store. Não adicione checkout externo ou carteira digital como API de
assinatura. Não marque configuração externa ou teste físico como concluído sem evidência. Não amplie o escopo além do manifesto MVP.
```

### Definition of Done por tarefa

- [ ] Aceite demonstrado e checks pertinentes aprovados.
- [ ] Nenhum placeholder, mock ou fallback enganoso no caminho de produção alterado.
- [ ] Contrato, regra, índice e migração atualizados quando necessário.
- [ ] Logs/eventos suficientes para diagnosticar o fluxo, sem dados sensíveis.
- [ ] Tratamento de erro/retry consistente; isolamento e idempotência testados quando pertinentes.
- [ ] Evidência de staging anexada e runbook/rollback definido para mudança de risco.
- [ ] Configuração externa e testes físicos distinguidos de testes locais.

## 14. Referências para implementação

Consultadas em 16/10/2026. Revalidar SDKs, políticas e configuração comercial na implementação/submissão. Os procedimentos deste documento são decisões de engenharia; documentação externa não substitui testes no projeto.

- [Google — Payments policy e assinaturas digitais](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en).
- [Apple — App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), especialmente assinaturas, compras e categoria infantil.
- [Google — Segurança e validação de compras](https://developer.android.com/google/play/billing/security).
- [Google — Ciclo de vida de assinaturas](https://developer.android.com/google/play/billing/lifecycle/subscriptions).
- [Google — RTDN](https://developer.android.com/google/play/billing/rtdn-reference).
- [Google — Acesso à Developer API](https://developers.google.com/android-publisher/getting_started).
- [Apple — Assinaturas autorrenováveis](https://developer.apple.com/app-store/subscriptions/).
- [Apple — App Store Server API](https://developer.apple.com/documentation/appstoreserverapi).
- [Apple — Server Notifications](https://developer.apple.com/documentation/appstoreservernotifications).
- [Apple — Biblioteca oficial Node para Server API e verificação](https://github.com/apple/app-store-server-library-node).
- [Flutter — Plugin oficial `in_app_purchase`](https://pub.dev/packages/in_app_purchase).
- [Firebase — App Check no Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers).

## 15. Primeira entrega concreta

Começar por **F0 + T01–T04**, fechando configuração Firebase/App Check e a brecha de recompensa. Entregar build staging instalável, testes de confiança aprovados e decisões D01–D09 registradas, produtos das lojas em preparação e spike do plugin concluído. Só avançar o beta para famílias quando a troca de conta e o isolamento por criança também estiverem demonstrados.
