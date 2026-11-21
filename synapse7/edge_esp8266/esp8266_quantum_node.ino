/*
  ============================================================================
  SYNAPSE-7: Edge ESP8266 Post-Quantum Wireless Bridge & QKD Broker
  Target Hardware: ESP8266 (NodeMCU v2 / ESP-01 / Wemos D1 Mini)
  Interface: Hardware UART @ 115200 baud -> Digilent Arty S7 (Pmod JA)
  Author: Arunjyoti Sarma (IIT BHU)
  ============================================================================
*/

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <WiFiClient.h>

const char* ssid = "SYNAPSE7_QUANTUM_NET";
const char* password = "alien_quantum_security_2026";

ESP8266WebServer server(80);

// Status registers
unsigned long packetCount = 0;
String lastFpgaResponse = "NONE";
String activeQuantumKey = "0x8F92E47B1A2C3D5E6F7A8B9C0D1E2F3A4B5C6D7E8F9A0B1C2D3E4F5A6B7C8D9E";

// Command codes for Spartan-7 QPU
const char CMD_PING   = 'Q';
const char CMD_STEANE = 'S';
const char CMD_NTT    = 'N';

void handleRoot() {
  String html = "<!DOCTYPE html><html><head><title>SYNAPSE-7 Edge Node</title>";
  html += "<style>body{background:#0a0e17;color:#00ffcc;font-family:monospace;padding:20px;}";
  html += ".card{border:1px solid #00ffcc;padding:15px;margin:10px 0;background:#111927;}";
  html += "h1{color:#ff0055;} button{background:#ff0055;color:#fff;border:none;padding:10px;cursor:pointer;font-weight:bold;}</style></head>";
  html += "<body><h1>[SYNAPSE-7] ESP8266 QUANTUM EDGE BRIDGE</h1>";
  html += "<div class='card'><h3>FPGA LINK STATUS</h3>";
  html += "<p>Hardware Target: Digilent Arty S7 (Spartan-7 XC7S50)</p>";
  html += "<p>UART Baud: 115200 bps | Packets Handled: " + String(packetCount) + "</p>";
  html += "<p>Last FPGA Telemetry: " + lastFpgaResponse + "</p></div>";
  html += "<div class='card'><h3>POST-QUANTUM KEY ESCROW</h3>";
  html += "<p>Active 256-bit Key: " + activeQuantumKey + "</p>";
  html += "<a href='/fpga/ping'><button>PING FPGA QPU</button></a> ";
  html += "<a href='/fpga/steane'><button>TEST STEANE [[7,1,3]] CODE</button></a> ";
  html += "<a href='/fpga/ntt'><button>TRIGGER NTT BUTTERFLY</button></a>";
  html += "</div></body></html>";
  server.send(200, "text/html", html);
}

void handleFpgaPing() {
  Serial.write(CMD_PING);
  packetCount++;
  delay(50);
  if (Serial.available()) {
    byte resp = Serial.read();
    lastFpgaResponse = "ACK_0x" + String(resp, HEX);
  } else {
    lastFpgaResponse = "SIMULATED_ACK_0xA7 (Hardware Loopback Pending)";
  }
  server.sendHeader("Location", "/");
  server.send(303);
}

void handleFpgaSteane() {
  Serial.write(CMD_STEANE);
  packetCount++;
  delay(50);
  if (Serial.available()) {
    byte resp = Serial.read();
    lastFpgaResponse = "STEANE_SYNDROME_0x" + String(resp, HEX);
  } else {
    lastFpgaResponse = "STEANE_CORRECTED_Q2 (Simulated Arty S7 Bitstream)";
  }
  server.sendHeader("Location", "/");
  server.send(303);
}

void handleFpgaNtt() {
  Serial.write(CMD_NTT);
  packetCount++;
  delay(50);
  if (Serial.available()) {
    byte resp = Serial.read();
    lastFpgaResponse = "NTT_BUTTERFLY_OUT_0x" + String(resp, HEX);
  } else {
    lastFpgaResponse = "NTT_COMPLETED_U120_V45 (Simulated Arty S7 Bitstream)";
  }
  server.sendHeader("Location", "/");
  server.send(303);
}

void setup() {
  // UART setup for direct communication with Spartan-7 Pmod JA
  Serial.begin(115200);
  
  // Set ESP8266 as Access Point + Station
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(ssid, password);
  
  server.on("/", handleRoot);
  server.on("/fpga/ping", handleFpgaPing);
  server.on("/fpga/steane", handleFpgaSteane);
  server.on("/fpga/ntt", handleFpgaNtt);
  server.begin();
}

void loop() {
  server.handleClient();
  
  // Forward any incoming FPGA spontaneous telemetry
  if (Serial.available()) {
    byte b = Serial.read();
    lastFpgaResponse = "INCOMING_0x" + String(b, HEX);
  }
}
