import { CollectionOptions } from ".";
import Document from "./Document";

declare class Collection<T> {
    private dataStore: DataStore
    private options: CollectionOptions<T> 
    readonly openDocuments: Record<string, Document<T>>

    // as I'm using export =, I can only export one thing.
    // therefore, I'm importing CollectionOptions from index.d.ts where it is also referenced
    constructor(name: string, options: CollectionOptions<T>)

    Load(key: string): Promise<Document<T>>
}

export = Collection;
