import sequelize, { Sequelize } from 'sequelize';
import {initModels} from "./init-models";

export type DB = {
    sequelize: Sequelize,
    Sequelize: any,
}

const seq = new Sequelize(process.env.DMD_DB_API_NAME || 'postgres', process.env.DMD_DB_API_USER || 'diamond_api', process.env.DMD_DB_API_PASS, {
        host: process.env.DMD_DB_API_HOST || 'db',
        port: Number(process.env.DMD_DB_API_PORT) || 5432,
        dialect: 'postgres', // or 'mysql', 'sqlite', etc.
    });
const db: DB = {
    sequelize: seq,
    Sequelize: sequelize,
};
initModels(seq);


export default db;
