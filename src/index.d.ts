import Collection from "./Collection";

interface LapisConfig {
    /** Max save/close retry attempts */
    saveAttempts: number;
    /** Max lock acquire retry attempts */
	loadAttempts: number;
    /** Seconds between lock acquire attempts */
    loadRetryDelay: number;
    /** Show warning on retry */
	showRetryWarnings: boolean;
    // only require 2 methods for mocking :)
    /** Useful for mocking DataStoreService, especially in a local place */
	dataStoreService: Pick<DataStoreService, "GetDataStore" | "GetRequestBudgetForRequestType">;
}

export function setConfig(config: Partial<LapisConfig>): void

export interface CollectionOptions<T> {
    /** Takes a document's data and returns true on success or false and an error on fail. */
    validate: (data: T) => true | LuaTuple<[false, string]>
    defaultData: T
    /** Migrations take old data and return new data. Order is first to last. */
    migrations: Array<(data: T) => T>
}

export function createCollection<T>(name: string, options: CollectionOptions<T>): Collection<T>
