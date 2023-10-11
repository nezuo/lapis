export type Autosave<T> = {
	addDocument: (Autosave<T>, Document<T>) -> (),
	data: Data<T>,
	documents: { Document<T> },
	onGameClose: (Autosave<T>) -> (),
	removeDocument: (Autosave<T>, Document<T>) -> (),
	start: (Autosave<T>) -> (),
}

export type CollectionOptions<T> = {
	defaultData: T,
	migrations: { (unknown) -> unknown | (unknown) -> T },
	validate: (T) -> boolean,
}

export type Collection<T> = {
	autoSave: Autosave<T>,
	data: Data<T>,
	dataStore: DataStore,
	load: (self: Collection<T>, key: string) -> TypedPromise<Document<T>>,
	openDocuments: { [string]: TypedPromise<Document<T>> },
	options: CollectionOptions<T>,
}

export type LapisConfigValues = {
	dataStoreService: DataStoreService,
	loadAttempts: number,
	loadRetryDelay: number,
	saveAttempts: number,
	showRetryWarnings: boolean,
}

export type Config = {
	config: LapisConfigValues,
	get: (Config, string) -> (number | boolean | DataStoreService)?,
	set: (Config, { [string]: number | boolean | DataStoreService }) -> (),
}

export type Data<T> = {
	config: Config,
	load: (Data<T>, DataStore, string, (T) -> T) -> TypedPromise<T>,
	ongoingSaves: { [DataStore]: { [string]: Promise } },
	save: (Data<T>, DataStore, string, (T) -> T) -> TypedPromise<T>,
	throttle: Throttle<T>,
	waitForOngoingSave: (Data<T>, DataStore, string) -> Promise,
	waitForOngoingSaves: (Data<T>) -> Promise,
}

export type Document<T> = {
	close: (Document<T>) -> Promise,
	collection: Collection<T>,
	data: T,
	key: string,
	lockId: string,
	read: (Document<T>) -> T,
	save: (Document<T>) -> TypedPromise<T>,
	validate: (T) -> boolean,
	write: (Document<T>, T) -> (),
}

export type Internal<T> = {
	autoSave: Autosave<T>?,
	createCollection: <U>(name: string, options: CollectionOptions<U>) -> Collection<U>,
	setConfig: (values: PartialLapisConfigValues) -> (),
}

export type Throttle<T> = {
	config: Config,
	getUpdateAsyncBudget: (Throttle<T>) -> number,
	queue: { number },
	start: (Throttle<T>) -> (),
	updateAsync: (Throttle<T>, DataStore, string, (T) -> T, number, number) -> TypedPromise<T>,
}

export type PartialLapisConfigValues = {
	dataStoreService: DataStoreService?,
	loadAttempts: number?,
	loadRetryDelay: number?,
	saveAttempts: number?,
	showRetryWarnings: boolean?,
}

export type Status = "Started" | "Resolved" | "Rejected" | "Cancelled"

export type Promise = {
	andThen: (
		self: Promise,
		successHandler: (...any) -> ...any,
		failureHandler: ((...any) -> ...any)?
	) -> Promise,
	andThenCall: <TArgs...>(self: Promise, callback: (TArgs...) -> ...any, TArgs...) -> any,
	andThenReturn: (self: Promise, ...any) -> Promise,

	await: (self: Promise) -> (boolean, ...any),
	awaitStatus: (self: Promise) -> (Status, ...any),

	cancel: (self: Promise) -> (),
	catch: (self: Promise, failureHandler: (...any) -> ...any) -> Promise,
	expect: (self: Promise) -> ...any,

	finally: (self: Promise, finallyHandler: (status: Status) -> ...any) -> Promise,
	finallyCall: <TArgs...>(self: Promise, callback: (TArgs...) -> ...any, TArgs...) -> Promise,
	finallyReturn: (self: Promise, ...any) -> Promise,

	getStatus: (self: Promise) -> Status,
	now: (self: Promise, rejectionValue: any?) -> Promise,
	tap: (self: Promise, tapHandler: (...any) -> ...any) -> Promise,
	timeout: (self: Promise, seconds: number, rejectionValue: any?) -> Promise,
}

export type TypedPromise<T...> = {
	andThen: (self: Promise, successHandler: (T...) -> ...any, failureHandler: ((...any) -> ...any)?) -> Promise,
	andThenCall: <TArgs...>(self: Promise, callback: (TArgs...) -> ...any, TArgs...) -> Promise,
	andThenReturn: (self: Promise, ...any) -> Promise,

	await: (self: Promise) -> (boolean, T...),
	awaitStatus: (self: Promise) -> (Status, T...),

	cancel: (self: Promise) -> (),
	catch: (self: Promise, failureHandler: (...any) -> ...any) -> Promise,
	expect: (self: Promise) -> T...,

	finally: (self: Promise, finallyHandler: (status: Status) -> ...any) -> Promise,
	finallyCall: <TArgs...>(self: Promise, callback: (TArgs...) -> ...any, TArgs...) -> Promise,
	finallyReturn: (self: Promise, ...any) -> Promise,

	getStatus: (self: Promise) -> Status,
	now: (self: Promise, rejectionValue: any?) -> Promise,
	tap: (self: Promise, tapHandler: (T...) -> ...any) -> Promise,
	timeout: (self: Promise, seconds: number, rejectionValue: any?) -> Promise,
}

return nil
