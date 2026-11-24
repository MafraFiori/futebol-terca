using { futebol } from '../db/schema';

service AdminService {
    entity Players as projection on futebol.Players excluding { passwordHash };
}