package br.com.fiap.veai.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import io.swagger.v3.oas.models.info.Info;

class OpenApiConfigTest {

    private final Info info = new OpenApiConfig().openApi().getInfo();

    @Test
    void versaoDaApiEh110() {
        assertThat(info.getVersion()).isEqualTo("1.1.0");
    }

    @Test
    void descricaoDestacaOModoAutomatico() {
        assertThat(info.getDescription()).contains("modo automático");
    }
}
