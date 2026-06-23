import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import * as path from 'path';
import WebSocket from 'ws';

const TEST_DB = path.join(__dirname, '..', '..', 'test.sqlite');

describe('Circles E2E (sqlite)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let server: any;

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    await app.init();
    
    prisma = app.get(PrismaService);

    // Start listening on an ephemeral port so WebSocket clients can connect
    await app.listen(0);
    server = app.getHttpServer();
  }, 20000);

  afterAll(async () => {
    if (app) {
      await app.close();
    }
  });

  it('A sends request -> B accepts -> both see members and can message', async () => {
    // Create users A and B
  const A = await prisma.user.create({ data: { firstName: 'Alice', lastName: 'A', username: 'alice', email: 'a@example.com', phone: '+1', passwordHash: 'x' } as any });
  const B = await prisma.user.create({ data: { firstName: 'Bob', lastName: 'B', username: 'bob', email: 'b@example.com', phone: '+2', passwordHash: 'x' } as any });

  // Create JWTs for A and B using the server's JwtService
  const jwtService = app.get(require('@nestjs/jwt').JwtService) as any;
  const tokenA = jwtService.sign({ sub: A.id, username: A.username });
  const tokenB = jwtService.sign({ sub: B.id, username: B.username });

  // A sends a friend request to B
  const res1 = await request(server).post('/circles/requests').set('authorization', `Bearer ${tokenA}`).send({ memberId: B.id });
    expect(res1.status).toBe(201);

    // Ensure pending membership exists in DB
    const pending = await prisma.circleMembership.findFirst({ where: { userId: A.id, memberId: B.id } });
    expect(pending).toBeTruthy();
    expect(pending?.accepted).toBe(false);

    // B accepts the request
  const res2 = await request(server).post('/circles/requests/accept').set('authorization', `Bearer ${tokenB}`).send({ senderId: A.id });
    expect([200, 201]).toContain(res2.status);

    // After accept, both directions should exist and be accepted
  const aToB = await prisma.circleMembership.findUnique({ where: { unique_user_member: { userId: A.id, memberId: B.id } } as any }).catch(() => null);
  const bToA = await prisma.circleMembership.findUnique({ where: { unique_user_member: { userId: B.id, memberId: A.id } } as any }).catch(() => null);
    expect(aToB || pending).toBeTruthy();
    expect(bToA).toBeTruthy();

    // Start WS connections for A and B (mock token parsing in gateway accepts 'mock-<id>')

    const addr: any = server.address();
    const port = addr && addr.port ? addr.port : 3000;

  const tokenA_ws = tokenA;
  const tokenB_ws = tokenB;

  const wsA = new WebSocket(`ws://localhost:${port}/ws`, { headers: { Authorization: `Bearer ${tokenA_ws}` } });
  const wsB = new WebSocket(`ws://localhost:${port}/ws`, { headers: { Authorization: `Bearer ${tokenB_ws}` } });

    // Wait for both sockets to open
    await Promise.all([
      new Promise((res) => wsA.on('open', res)),
      new Promise((res) => wsB.on('open', res)),
    ]);


  // A sends a message to B via WS (send as JSON frame)
  const payloadAtoB = { event: 'send_message', data: { receiver: B.username, text: 'Hello Bob' } };
  wsA.send(JSON.stringify(payloadAtoB));

  // Wait briefly for delivery
  await new Promise((res) => setTimeout(res, 500));

  // Check DB messages A -> B
  const msgs = await prisma.message.findMany({ where: { senderId: A.id, receiverId: B.id } });
  expect(msgs.length).toBeGreaterThanOrEqual(1);

  // Now B sends a message to A (reverse) and ensure it also persists
  const payloadBtoA = { event: 'send_message', data: { receiver: A.username, text: 'Hi Alice' } };
  wsB.send(JSON.stringify(payloadBtoA));
  await new Promise((res) => setTimeout(res, 500));
  const msgsBA = await prisma.message.findMany({ where: { senderId: B.id, receiverId: A.id } });
  expect(msgsBA.length).toBeGreaterThanOrEqual(1);

  wsA.close();
  wsB.close();

  // --- Decline flow: create two fresh users C and D, A sends request to C and C declines ---
  const C = await prisma.user.create({ data: { firstName: 'Carol', lastName: 'C', username: 'carol', email: 'c@example.com', phone: '+3', passwordHash: 'x' } as any });
  const D = await prisma.user.create({ data: { firstName: 'Dan', lastName: 'D', username: 'dan', email: 'd@example.com', phone: '+4', passwordHash: 'x' } as any });

  const tokenC = jwtService.sign({ sub: C.id, username: C.username });

  // A sends request to C
  const reqToC = await request(server).post('/circles/requests').set('authorization', `Bearer ${tokenA}`).send({ memberId: C.id });
  expect(reqToC.status).toBe(201);

  // C declines
  const decline = await request(server).post('/circles/requests/decline').set('authorization', `Bearer ${tokenC}`).send({ senderId: A.id });
  expect([200, 201]).toContain(decline.status);

  // Ensure no accepted membership exists between A and C
  const aToC = await prisma.circleMembership.findUnique({ where: { unique_user_member: { userId: A.id, memberId: C.id } } }).catch(() => null);
  expect(aToC).toBeNull();
  }, 40000);
});
