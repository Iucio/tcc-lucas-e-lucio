

BEGIN;



CREATE TYPE perfil_usuario AS ENUM ('admin', 'supervisor', 'operador', 'qualidade', 'pcp');

CREATE TYPE status_op AS ENUM ('planejada', 'em_producao', 'pausada', 'finalizada', 'cancelada');

CREATE TYPE status_pallet AS ENUM ('em_espera', 'parcial', 'finalizado');


CREATE TABLE usuario (
    id_usuario      SERIAL PRIMARY KEY,
    nome            VARCHAR(120) NOT NULL,
    perfil          perfil_usuario NOT NULL,
    ativo           BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE galpao (
    id_galpao       SERIAL PRIMARY KEY,
    codigo          VARCHAR(20) NOT NULL UNIQUE,
    descricao       VARCHAR(200)
);

CREATE TABLE posicao_estoque (
    id_posicao      SERIAL PRIMARY KEY,
    id_galpao       INTEGER NOT NULL REFERENCES galpao(id_galpao),
    nro_bloco       VARCHAR(20) NOT NULL,
    andar           VARCHAR(10) NOT NULL,
    nro_rua         VARCHAR(20) NOT NULL,
    CONSTRAINT uq_posicao UNIQUE (id_galpao, nro_bloco, andar, nro_rua)
);

CREATE TABLE produto_produzido (
    id_produto           SERIAL PRIMARY KEY,
    sku                  VARCHAR(40) NOT NULL UNIQUE,
    nome                 VARCHAR(150) NOT NULL,
    ativo                BOOLEAN NOT NULL DEFAULT TRUE,
    peso_sache_kg        NUMERIC(10,4),
    qtd_padrao_pallet    INTEGER,          
    saches_por_fardo_cx  INTEGER,
    eh_instantaneo       BOOLEAN NOT NULL DEFAULT FALSE,
    eh_vitaminado        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE insumos (
    id_insumos        SERIAL PRIMARY KEY,
    nome              VARCHAR(150) NOT NULL,
    descricao         VARCHAR(300),
    unidade           VARCHAR(10) NOT NULL,
    embalagem_padrao  VARCHAR(80),
    qtd_padrao        NUMERIC(12,4)
);

CREATE TABLE item_nfe (
    id_item_nfe       SERIAL PRIMARY KEY,
    linha             INTEGER,
    cfop              VARCHAR(10),
    und_medida        VARCHAR(10),
    cst               VARCHAR(10),       
    ncm_sh            VARCHAR(15),
    qtd               NUMERIC(14,4) NOT NULL DEFAULT 0,
    valor_unitario    NUMERIC(14,4) NOT NULL DEFAULT 0,
    valor_icms        NUMERIC(14,4) DEFAULT 0,
    base_calculo_icms NUMERIC(14,4) DEFAULT 0,
    aliquota_ipi      NUMERIC(6,4),
    aliquota_icms     NUMERIC(6,4),
    valor_total       NUMERIC(16,4) GENERATED ALWAYS AS (qtd * valor_unitario) STORED
);


CREATE TABLE ordem_producao (
    id_op                    SERIAL PRIMARY KEY,
    id_produto               INTEGER NOT NULL REFERENCES produto_produzido(id_produto),
    id_usuario_responsavel   INTEGER NOT NULL REFERENCES usuario(id_usuario),
    status                   status_op NOT NULL DEFAULT 'planejada',
    total_kg                 NUMERIC(14,3),
    data_fabricacao          DATE,
    data_validade            DATE,
    qtd_pcp                  NUMERIC(14,3),
    observacoes              TEXT,
    inicio                   TIMESTAMP,
    fim                      TIMESTAMP,
    CONSTRAINT chk_op_periodo CHECK (fim IS NULL OR inicio IS NULL OR fim >= inicio)
);

-- DEVERIA SER HASH
CREATE INDEX idx_op_status ON ordem_producao(status);
-- DEVERIA SER HASH
CREATE INDEX idx_op_produto ON ordem_producao(id_produto);

CREATE TABLE execucao_ordem_producao_insumo (
    id_op            INTEGER NOT NULL REFERENCES ordem_producao(id_op) ON DELETE CASCADE,
    id_insumos       INTEGER NOT NULL REFERENCES insumos(id_insumos),
    qtd_consumidas   NUMERIC(14,4) NOT NULL DEFAULT 0,
    qtd_perdidas     NUMERIC(14,4) NOT NULL DEFAULT 0,
    PRIMARY KEY (id_op, id_insumos)
);


CREATE TABLE execucao_ordem_producao_item_nfe (
    id_op            INTEGER NOT NULL REFERENCES ordem_producao(id_op) ON DELETE CASCADE,
    id_item_nfe      INTEGER NOT NULL REFERENCES item_nfe(id_item_nfe),
    qtd_consumidos   NUMERIC(14,4) NOT NULL DEFAULT 0,
    qtd_perdidas     NUMERIC(14,4) NOT NULL DEFAULT 0,
    PRIMARY KEY (id_op, id_item_nfe)
);


CREATE TABLE sessao (
    id_sessao                  SERIAL PRIMARY KEY,
    id_op                      INTEGER NOT NULL REFERENCES ordem_producao(id_op),
    id_usuario_operador        INTEGER NOT NULL REFERENCES usuario(id_usuario),
    hora_programada_inicio     TIMESTAMP,
    hora_programada_fim        TIMESTAMP,
    hora_real_inicio           TIMESTAMP,
    hora_real_fim              TIMESTAMP,
    motivo_atraso              VARCHAR(200),
    atraso_minutos             INTEGER,
    total_saches_produzidos    INTEGER NOT NULL DEFAULT 0,
    total_perdas_varredura     INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_sessao_op ON sessao(id_op);

CREATE TABLE parada (
    id_sessao           INTEGER NOT NULL REFERENCES sessao(id_sessao) ON DELETE CASCADE,
    nro_parada          INTEGER NOT NULL,
    ppm                 NUMERIC(10,2),
    tipo                VARCHAR(50),
    dt_hr_inicio        TIMESTAMP,
    dt_hr_fim           TIMESTAMP,
    saches_acumulados   INTEGER,
    status              VARCHAR(30),
    categoria           VARCHAR(50),
    PRIMARY KEY (id_sessao, nro_parada)
);


CREATE TABLE pallet_acabado (
    id_pallet                  UUID PRIMARY KEY,
    id_sessao                  INTEGER NOT NULL REFERENCES sessao(id_sessao),
    id_posicao_estoque         INTEGER REFERENCES posicao_estoque(id_posicao),
    id_usuario_paletizador     INTEGER REFERENCES usuario(id_usuario),
    etiqueta_qr                VARCHAR(80) UNIQUE,
    status                     status_pallet NOT NULL DEFAULT 'em_espera',
    total_kg                   NUMERIC(14,3) NOT NULL DEFAULT 0,
    qtd_items                  INTEGER NOT NULL DEFAULT 0,
    data_hora_inicio           TIMESTAMP,
    data_hora_fim               TIMESTAMP,
    data_hr_conf               TIMESTAMP,
    data_inspecao              TIMESTAMP,
    total_kg_parcial           NUMERIC(14,3) NOT NULL DEFAULT 0
);

CREATE INDEX idx_pallet_sessao ON pallet_acabado(id_sessao);

CREATE TABLE pallet_parcial_acabado (
    id_pallet           UUID NOT NULL REFERENCES pallet_acabado(id_pallet_qr) ON DELETE CASCADE,
    nro                 INTEGER NOT NULL,
    total_kg            NUMERIC(14,3) NOT NULL DEFAULT 0,
    data_inspecao       TIMESTAMP,
    qtd_fardos_parcial  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (id_pallet, nro)
);


CREATE TABLE pallet_final_encartuchado (
    id_pallet_encartuchado   UUID NOT NULL REFERENCES pallet_acabado(id_pallet),
    id_usuario_responsavel   INTEGER NOT NULL REFERENCES usuario(id_usuario),
    PRIMARY KEY (id_pallet_encartuchado)
);

CREATE TABLE pallet_origem_encartuchado (
    id_pallet_encartuchado   UUID NOT NULL REFERENCES pallet_acabado(id_pallet_qr),
    id_pallet_origem         UUID NOT NULL REFERENCES pallet_acabado(id_pallet),
    PRIMARY KEY (id_pallet_encartuchado, id_pallet_origem)
);




CREATE INDEX idx_encart_pallet ON encartuchamento(id_pallet_qr);

COMMIT;


CREATE OR REPLACE VIEW vw_ordens_em_producao_tempo AS
SELECT
    op.id_op,
    op.status,
    pp.sku,
    pp.nome                                            AS produto,
    u.nome                                             AS responsavel,
    op.inicio,
    op.fim,
    op.data_fabricacao,
    op.data_validade,
    (op.fim IS NULL AND op.inicio IS NOT NULL)         AS em_producao,
    (COALESCE(op.fim, now()) - op.inicio)              AS tempo_producao,
    ROUND(
        EXTRACT(EPOCH FROM (COALESCE(op.fim, now()) - op.inicio)) / 3600.0,
        2
    )                                                   AS horas_em_producao
FROM ordem_producao op
JOIN produto_produzido pp ON pp.id_produto = op.id_produto
JOIN usuario u             ON u.id_usuario  = op.id_usuario_responsavel
WHERE op.status = 'em_producao'
   OR (op.inicio IS NOT NULL AND op.fim IS NULL)
ORDER BY op.inicio ASC;

COMMENT ON VIEW vw_ordens_em_producao_tempo IS
    'Ordens de produção atualmente em andamento, com tempo decorrido desde o início.';



CREATE OR REPLACE FUNCTION fn_valida_pallet_parcial()
RETURNS TRIGGER AS $$
DECLARE
    v_status status_pallet;
BEGIN
    SELECT status INTO v_status
    FROM pallet_acabado
    WHERE id_pallet_qr = NEW.id_pallet_qr
    FOR UPDATE;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Pallet acabado % não encontrado.', NEW.id_pallet_qr;
    END IF;

    IF v_status = 'finalizado' THEN
        RAISE EXCEPTION
            'Não é possível incluir/alterar pallet parcial: o pallet % já está "finalizado".',
            NEW.id_pallet_qr;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_valida_pallet_parcial
    BEFORE INSERT OR UPDATE ON pallet_parcial_acabado
    FOR EACH ROW
    EXECUTE FUNCTION fn_valida_pallet_parcial();


CREATE OR REPLACE FUNCTION fn_atualiza_totais_pallet_acabado()
RETURNS TRIGGER AS $$
DECLARE
    v_id_pallet VARCHAR(50);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id_pallet := OLD.id_pallet_qr;
    ELSE
        v_id_pallet := NEW.id_pallet_qr;
    END IF;

    UPDATE pallet_acabado pa
    SET total_kg_parcial = sub.soma_kg,
        qtd_fardos_parcial_total = sub.soma_fardos,
        status = CASE
                    WHEN pa.status = 'em_espera' AND sub.soma_fardos > 0 THEN 'parcial'::status_pallet
                    ELSE pa.status
                 END
    FROM (
        SELECT
            COALESCE(SUM(total_kg), 0)            AS soma_kg,
            COALESCE(SUM(qtd_fardos_parcial), 0)   AS soma_fardos
        FROM pallet_parcial_acabado
        WHERE id_pallet_qr = v_id_pallet
    ) sub
    WHERE pa.id_pallet_qr = v_id_pallet;

    IF TG_OP = 'UPDATE' AND OLD.id_pallet_qr IS DISTINCT FROM NEW.id_pallet_qr THEN
        UPDATE pallet_acabado pa
        SET total_kg_parcial = sub.soma_kg,
            qtd_fardos_parcial_total = sub.soma_fardos
        FROM (
            SELECT
                COALESCE(SUM(total_kg), 0)            AS soma_kg,
                COALESCE(SUM(qtd_fardos_parcial), 0)   AS soma_fardos
            FROM pallet_parcial_acabado
            WHERE id_pallet_qr = OLD.id_pallet_qr
        ) sub
        WHERE pa.id_pallet_qr = OLD.id_pallet_qr;
    END IF;

    RETURN NULL; 
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualiza_totais_pallet_acabado
    AFTER INSERT OR UPDATE OR DELETE ON pallet_parcial_acabado
    FOR EACH ROW
    EXECUTE FUNCTION fn_atualiza_totais_pallet_acabado();

